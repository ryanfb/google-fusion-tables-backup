#!/usr/bin/env ruby

require 'rubygems'
require 'fileutils'
require 'yaml'
require 'csv'

require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/file_storage'
require 'google/api_client/auth/installed_app'

API_VERSION = 'v2'
CACHED_API_FILE = ".google-fusiontables-#{API_VERSION}.cache"
CREDENTIAL_STORE_FILE = ".google-oauth2.json"

MAX_RETRIES = 5

def dump_table(fusion_table, backup_directory)
  backup_directory ||= "backups"
  FileUtils.mkdir_p backup_directory
  filename = File.join(backup_directory ,"#{fusion_table.name}-#{fusion_table.id}.csv")
  $stderr.puts filename
  retries = 0

  begin
    fusion_table_data = fusion_table.select

    CSV.open(filename, 'w') do |csv|
      if fusion_table_data.length > 0
        csv << fusion_table_data.first.keys
        fusion_table_data.each do |data|
          csv << data.values
        end
      end
    end
  rescue Exception => e
    $stderr.puts e.inspect
    if retries < MAX_RETRIES
      retries += 1
      $stderr.puts "Retry #{retries}"
      retry
    end
  end
end

# config = YAML.load_file('.secrets.yml')

client = Google::APIClient.new(:application_name => 'google-fusion-tables-backup',:application_version => '0.1.0')
# FileStorage stores auth credentials in a file, so they survive multiple runs
# of the application. This avoids prompting the user for authorization every
# time the access token expires, by remembering the refresh token.
# Note: FileStorage is not suitable for multi-user applications.
file_storage = Google::APIClient::FileStorage.new(CREDENTIAL_STORE_FILE)
if file_storage.authorization.nil?
  client_secrets = Google::APIClient::ClientSecrets.load
  # The InstalledAppFlow is a helper class to handle the OAuth 2.0 installed
  # application flow, which ties in with FileStorage to store credentials
  # between runs.
  flow = Google::APIClient::InstalledAppFlow.new(
    :client_id => client_secrets.client_id,
    :client_secret => client_secrets.client_secret,
    :scope => ['https://www.googleapis.com/auth/fusiontables']
  )
  client.authorization = flow.authorize(file_storage)
else
  client.authorization = file_storage.authorization
end

fusion_tables = nil
# Load cached discovered API, if it exists. This prevents retrieving the
# discovery document on every run, saving a round-trip to API servers.
if File.exists? CACHED_API_FILE
  File.open(CACHED_API_FILE) do |file|
    fusion_tables = Marshal.load(file)
  end
else
  fusion_tables = client.discovered_api('fusiontables', API_VERSION)
  File.open(CACHED_API_FILE, 'w') do |file|
    Marshal.dump(fusion_tables, file)
  end
end

# fusion_tables = GData::Client::FusionTables.new
# fusion_tables.clientlogin(config["email"], config["pass"])
# fusion_tables.set_api_key(config["api_key"])

if ARGV[1].nil?
  # back up all tables
  # fusion_tables.show_tables.map {|ft| dump_table(ft, ARGV[0])}
  result = client.execute(:api_method => fusion_tables.table.list)
  jj result.data.to_hash
else
  # back up a specific table
  # fusion_tables.show_tables.select {|ft| ft.id == ARGV[1]}.map {|ft| dump_table(ft, ARGV[0])}
end
