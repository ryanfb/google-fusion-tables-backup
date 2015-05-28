#!/usr/bin/env ruby

require 'rubygems'
require 'fileutils'
require 'json'
require 'csv'

require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/file_storage'
require 'google/api_client/auth/installed_app'

API_VERSION = 'v2'
CACHED_API_FILE = ".google-fusiontables-#{API_VERSION}.cache"
CREDENTIAL_STORE_FILE = ".google-oauth2.json"

# takes a Fusion Table encrypted id and optional backup directory and dumps to CSV
def dump_table(client, fusion_tables, fusion_table_id, backup_directory)
  backup_directory ||= "backups"
  FileUtils.mkdir_p backup_directory

  fusion_table = client.execute(
    :api_method => fusion_tables.table.get,
    :parameters => {'tableId' => "#{fusion_table_id}"}
  )
  fusion_table.data.to_hash
  filename = File.join(backup_directory ,"#{fusion_table.data.to_hash['name']}-#{fusion_table_id}")
  $stderr.puts filename

  File.open("#{filename}.json","w") do |f|
    f.write(JSON.pretty_generate(fusion_table.data.to_hash))
  end

  result = client.execute(
    :api_method => fusion_tables.query.sql_get,
    :parameters => {'sql' => "SELECT * FROM #{fusion_table_id}"}
  )
  fusion_table_data = result.data.to_hash

  if fusion_table_data['error']
    if fusion_table_data['error']['errors'][0]['reason'] == 'responseSizeTooLarge'
      # use Fusion Tables V2 media downloads API
      result = client.execute(
        :api_method => fusion_tables.query.sql_get,
        :parameters => {'sql' => "SELECT * FROM #{fusion_table_id}", 'alt' => 'media'}
      )
      File.open("#{filename}.csv", 'w') { |file| file.write(result.response.body) }
    else
      $stderr.puts "Unhandled Error:"
      $stderr.puts fusion_table_data.inspect
    end
  else
    CSV.open("#{filename}.csv", 'w') do |csv|
      if fusion_table_data['rows'] && (fusion_table_data['rows'].length > 0)
        csv << fusion_table_data['columns']
        fusion_table_data['rows'].each do |row|
          csv << row
        end
      end
    end
  end
end

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

if ARGV[1].nil?
  # back up all tables
  result = client.execute(:api_method => fusion_tables.table.list)
  fusion_tables_list = result.data.to_hash
  fusion_tables_list['items'].map {|ft| dump_table(client, fusion_tables, ft['tableId'], ARGV[0])}
  while (fusion_tables_list['nextPageToken']) do
    $stderr.puts "Using page token #{fusion_tables_list['nextPageToken']} to fetch next page of tables"
    result = client.execute(
      :api_method => fusion_tables.table.list,
      :parameters => {'pageToken' => fusion_tables_list['nextPageToken']}
    )
    fusion_tables_list = result.data.to_hash
    fusion_tables_list['items'].map {|ft| dump_table(client, fusion_tables, ft['tableId'], ARGV[0])}
  end
else
  # back up a specific table
  dump_table(client, fusion_tables, ARGV[1], ARGV[0])
end
