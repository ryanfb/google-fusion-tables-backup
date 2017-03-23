#!/usr/bin/env ruby

require 'rubygems'
require 'fileutils'
require 'json'
require 'csv'

require 'google/apis/fusiontables_v2'

require 'googleauth'
require 'googleauth/stores/file_token_store'

CREDENTIAL_STORE_FILE = ".google-oauth2.yaml"

# takes a Fusion Table encrypted id and optional backup directory and dumps to CSV
def dump_table(fusion_tables, fusion_table_id, backup_directory)
  backup_directory ||= "backups"
  FileUtils.mkdir_p backup_directory

  fusion_table = fusion_tables.get_table(fusion_table_id)
  filename = File.join(backup_directory ,"#{fusion_table.name}-#{fusion_table_id}")
  $stderr.puts filename

  File.open("#{filename}.json","w") do |f|
    f.write(JSON.pretty_generate(fusion_table.to_h))
  end

  fusion_table_data = fusion_tables.sql_query_get("SELECT * FROM #{fusion_table_id}", download_dest: "#{filename}.csv")
end

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'

scope = 'https://www.googleapis.com/auth/fusiontables'
client_id = Google::Auth::ClientId.from_file(File.join(File.dirname(__FILE__),'client_secrets.json'))
token_store = Google::Auth::Stores::FileTokenStore.new(
  :file => CREDENTIAL_STORE_FILE)
authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)

user_id = 'default'
credentials = authorizer.get_credentials(user_id)
if credentials.nil?
  url = authorizer.get_authorization_url(base_url: OOB_URI )
  puts "Open #{url} in your browser and enter the resulting code:"
  code = STDIN.gets
  credentials = authorizer.get_and_store_credentials_from_code(
    user_id: user_id, code: code, base_url: OOB_URI)
end

fusion_tables = Google::Apis::FusiontablesV2::FusiontablesService.new # (:application_name => 'google-fusion-tables-backup',:application_version => '0.1.0')
fusion_tables.authorization = credentials

if ARGV[1].nil?
  # back up all tables
  fusion_tables_list = fusion_tables.list_tables
  loop do
    fusion_tables_list.items.map do |ft|
      begin
        dump_table(fusion_tables, ft.table_id, ARGV[0])
      rescue Google::Apis::ServerError => e
        $stderr.puts "Error dumping table: #{ft.table_id}"
        $stderr.puts e.inspect
      end
    end

    if fusion_tables_list.next_page_token
      $stderr.puts "Using page token #{fusion_tables_list.next_page_token} to fetch next page of tables"
      fusion_tables_list = fusion_tables.list_tables(page_token: fusion_tables_list.next_page_token)
    else
      break
    end
  end

  while (fusion_tables_list.next_page_token) do
    $stderr.puts "Using page token #{fusion_tables_list.next_page_token} to fetch next page of tables"
    fusion_tables_list = fusion_tables.list_tables(page_token: fusion_tables_list.next_page_token)
    fusion_tables_list.items.map {|ft| dump_table(fusion_tables, ft.table_id, ARGV[0])}
  end
else
  # back up a specific table
  dump_table(fusion_tables, ARGV[1], ARGV[0])
end
