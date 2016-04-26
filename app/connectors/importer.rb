# encoding: utf-8
require 'uuidtools'

require_relative '../models/visualization/support_tables'
require_relative '../helpers/bounding_box_helper'

require_dependency 'carto/physical_tables_manager'

module CartoDB
  module Connector
    class Importer
      ORIGIN_SCHEMA       = 'cdb_importer'
      DESTINATION_SCHEMA  = 'public'
      MAX_RENAME_RETRIES  = 20

      attr_reader :imported_table_visualization_ids, :rejected_layers
      attr_accessor :table

      # @param runner CartoDB::Importer2::Runner
      # @param table_registrar CartoDB::TableRegistrar
      # @param quota_checker CartoDB::QuotaChecker
      # @param database
      # @param data_import_id String UUID
      # @param destination_schema String|nil
      # @param public_user_roles Array|nil
      def initialize(runner, table_registrar, quota_checker, database, data_import_id,
                     overviews_creator,
                     destination_schema = DESTINATION_SCHEMA, public_user_roles=[CartoDB::PUBLIC_DB_USER])
        @aborted                = false
        @runner                 = runner
        @table_registrar        = table_registrar
        @quota_checker          = quota_checker
        @database               = database
        @data_import_id         = data_import_id
        @overviews_creator      = overviews_creator
        @destination_schema     = destination_schema
        @support_tables_helper  = CartoDB::Visualization::SupportTables.new(database,
                                                                            {public_user_roles: public_user_roles})

        @imported_table_visualization_ids = []
        @rejected_layers = []
      end

      def run(tracker)
        runner.run(&tracker)

        if quota_checker.will_be_over_table_quota?(results.length)
          runner.log.append('Results would set overquota')
          @aborted = true
          results.each { |result|
            drop(result.table_name)
          }
        else
          runner.log.append('Proceeding to register')
          results.select(&:success?).each { |result|
            register(result)
          }
          results.select(&:success?).each { |result|
            create_overviews(result)
          }

          if data_import.create_visualization
            create_visualization
          end
        end

        self
      end

      def register(result)
        @support_tables_helper.reset

        # Sanitizing table name if it corresponds with a PostgreSQL reseved word
        result.name = "#{result.name}_t" if CartoDB::POSTGRESQL_RESERVED_WORDS.map(&:downcase).include?(result.name.downcase)

        runner.log.append("Before renaming from #{result.table_name} to #{result.name}")
        name = rename(result, result.table_name, result.name)
        result.name = name
        runner.log.append("Before moving schema '#{name}' from #{ORIGIN_SCHEMA} to #{@destination_schema}")
        move_to_schema(result, name, ORIGIN_SCHEMA, @destination_schema)
        runner.log.append("Before persisting metadata '#{name}' data_import_id: #{data_import_id}")
        persist_metadata(result, name, data_import_id)
        runner.log.append("Table '#{name}' registered")
      rescue => exception
        if exception.message =~ /canceling statement due to statement timeout/i
          drop("#{ORIGIN_SCHEMA}.#{result.table_name}")
          raise CartoDB::Importer2::StatementTimeoutError.new(
            exception.message,
            CartoDB::Importer2::ERRORS_MAP[CartoDB::Importer2::StatementTimeoutError]
          )
        else
          raise exception
        end
      end

      def create_overviews(result)
        dataset = @overviews_creator.dataset(result.name)
        if dataset.should_create_overviews?
          dataset.create_overviews!
        end
      end

      def create_visualization
        tables = get_imported_tables
        if tables.length > 0
          user = ::User.where(id: data_import.user_id).first
          vis, @rejected_layers = CartoDB::Visualization::DerivedCreator.new(user, tables).create
          data_import.visualization_id = vis.id
          data_import.save
          data_import.reload
        end
      end

      def get_imported_tables
        tables = []
        @imported_table_visualization_ids.each do |table_id|
          vis = CartoDB::Visualization::Member.new(id: table_id).fetch
          tables << vis.table
        end
        tables
      end

      def success?
        !over_table_quota? && runner.success?
      end

      def drop_all(results)
        results.each { |result| drop(result.qualified_table_name) }
      end

      def drop(table_name)
        Carto::OverviewsService.new(database).delete_overviews table_name
        database.execute(%(DROP TABLE #{table_name}))
      rescue => exception
        runner.log.append("Couldn't drop table #{table_name}: #{exception}. Backtrace: #{exception.backtrace} ")
        self
      end

      def move_to_schema(result, table_name, origin_schema, destination_schema)
        return self if origin_schema == destination_schema

        database.execute(%Q{
          ALTER TABLE "#{origin_schema}"."#{table_name}"
          SET SCHEMA "#{destination_schema}"
        })

        @support_tables_helper.tables = result.support_tables.map { |table|
          { schema: origin_schema, name: table }
        }
        @support_tables_helper.change_schema(destination_schema, table_name)
      rescue => e
        drop("#{origin_schema}.#{table_name}")
        raise e
      end

      def rename(result, current_name, new_name, _rename_attempts = 0)
        valid_new_name = Carto::PhysicalTablesManager.new(table_registrar.user.id)
                                                     .propose_valid_table_name(contendent: new_name)

        database.execute(%{
          ALTER TABLE "#{ORIGIN_SCHEMA}"."#{current_name}" RENAME TO "#{valid_new_name}"
        })

        rename_the_geom_index_if_exists(current_name, valid_new_name)

        @support_tables_helper.tables = result.support_tables.map { |table|
          { schema: ORIGIN_SCHEMA, name: table }
        }

        recreate_constraints = false # Delay recreation of constraints until schema change
        results = @support_tables_helper.rename(current_name, valid_new_name, recreate_constraints)

        if results[:success]
          result.update_support_tables(results[:names])
        else
          raise 'unsuccessful support tables renaming'
        end

        valid_new_name
      end

      def rename_the_geom_index_if_exists(current_name, new_name)
        database.execute(%Q{
          ALTER INDEX IF EXISTS "#{ORIGIN_SCHEMA}"."#{current_name}_geom_idx"
          RENAME TO "the_geom_#{UUIDTools::UUID.timestamp_create.to_s.gsub('-', '_')}"
        })
      rescue => exception
        runner.log.append("Silently failed rename_the_geom_index_if_exists from #{current_name} to #{new_name} with exception #{exception}. Backtrace: #{exception.backtrace.to_s}. ")
      end

      def persist_metadata(result, name, data_import_id)
        table_registrar.register(name, data_import_id)
        @table = table_registrar.table
        @imported_table_visualization_ids << @table.table_visualization.id
        BoundingBoxHelper.update_visualizations_bbox(table)
        self
      end

      def results
        runner.results
      end

      def over_table_quota?
        @aborted || quota_checker.over_table_quota?
      end

      def error_code
        return 8002 if over_table_quota?
        results.map(&:error_code).compact.first
      end

      def data_import
        @data_import ||= DataImport[@data_import_id]
      end

      private

      def exists_user_table_for_user_id(table_name, user_id)
        !Carto::UserTable.where(name: table_name, user_id: user_id).first.nil?
      end

      attr_reader :runner, :table_registrar, :quota_checker, :database, :data_import_id

    end
  end
end
