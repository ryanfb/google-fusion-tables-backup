#!/usr/bin/env ruby

require 'rubygems'
require 'fusion_tables'
require 'yaml'
require 'csv'

MAX_RETRIES = 5

def dump_table(fusion_table, backup_directory)
  backup_directory ||= "backups"
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

config = YAML.load_file('.secrets.yml')
fusion_tables = GData::Client::FusionTables.new
fusion_tables.clientlogin(config["email"], config["pass"])
fusion_tables.set_api_key(config["api_key"])

if ARGV[1].nil?
  # back up all tables
  fusion_tables.show_tables.map {|ft| dump_table(ft, ARGV[0])}
else
  # back up a specific table
  fusion_tables.show_tables.select {|ft| ft.id == ARGV[1]}.map {|ft| dump_table(ft, ARGV[0])}
end