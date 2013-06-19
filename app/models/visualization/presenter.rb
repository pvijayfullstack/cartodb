# encoding: utf-8

module CartoDB
  module Visualization
    class Presenter
      def initialize(visualization, options={})
        @visualization  = visualization
        @options        = options
        @user           = options.fetch(:user, nil)
        @table          = options[:table] || visualization.table
      end #initialize

      def to_poro
        poro = {
          id:               visualization.id,
          name:             visualization.name,
          map_id:           visualization.map_id,
          active_layer_id:  visualization.active_layer_id,
          type:             visualization.type,
          tags:             visualization.tags,
          description:      visualization.description,
          privacy:          visualization.privacy.upcase,
          stats:            visualization.stats(user),
          created_at:       visualization.created_at,
          updated_at:       visualization.updated_at,
          table:            table_data_for(table)
        }
        poro.merge!(related) if options.fetch(:related, true)
        poro
      end #to_poro

      private

      attr_reader :visualization, :options, :user, :table

      def related
        { related_tables:   related_tables }
      end #related

      def table_data_for(table=nil)
        return {} unless table
        {
          id:               table.id,
          name:             table.name,
          privacy:          table.privacy_text,
          size:             table.table_size(user),
          row_count:        table.rows_estimated(user),
          updated_at:       table.updated_at
        }
      end #table_data_for

      def related_tables
        without_associated_table(visualization.related_tables)
          .map { |table| table_data_for(table) }
      end #related_tables

      def without_associated_table(tables)
        return tables unless visualization.table
        tables.select { |table| table.id != visualization.table.id }
      end #without_associated_table
    end # Presenter
  end # Visualization
end # CartoDB

