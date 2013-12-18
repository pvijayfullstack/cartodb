# encoding: utf-8
namespace :cartodb do
  namespace :db do
    desc 'Register ghost tables in metadata'
    task :register_ghost_tables => :environment do
      block = lambda { false }
      User.send(:define_method, :over_table_quota?, block)

      count = User.count
      User.all.each_with_index do |user, index|
        puts "Cleaning up importer tables for #{user.username}"
        begin
          table_names_in_database = user.in_database.fetch(%Q(
            SELECT table_name FROM information_schema.tables
            AS table_name
            WHERE table_schema = 'public'
          )).map { |record| record.fetch(:table_name) }

          table_names_in_metadata = user.tables.map(&:name)

          ghost_tables = table_names_in_metadata - table_names_in_database


          ghost_tables.map { |name|
            @table_name = name
            table = Table.new
            table.user_id = user.id
            table.migrate_existing_table = @table_name
            table.save
            puts "------ #{table.name} registered for user #{user.username}"
          }
          printf "OK %-#{20}s (%-#{4}s/%-#{4}s)\n", user.username, index, count
        rescue => exception
          printf "FAIL %-#{20}s (%-#{4}s/%-#{4}s) #{exception.message}\n", user.username, index, count
        end
        sleep(1.0/5.0)
      end
    end
  end
end
