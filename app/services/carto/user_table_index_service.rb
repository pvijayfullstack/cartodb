module Carto
  class UserTableIndexService
    AUTO_INDEX_PREFIX = '_auto_idx_'.freeze
    MINIMUM_ROW_COUNT_TO_INDEX = 10000
    INDEXABLE_WIDGET_TYPES = %w(histogram category time-series).freeze

    def initialize(user_table)
      @user_table = user_table
      @table = user_table.service
    end

    def generate_indices
      widget_columns = (@table.estimated_row_count > MINIMUM_ROW_COUNT_TO_INDEX) ? columns_with_widgets : []
      columns_to_index = widget_columns.select { |c| indexable_column?(c) }

      auto_indexed_columns = auto_indices.map { |i| i[:column] }
      indexed_columns = indices.map { |i| i[:column] }

      create_index_on = columns_to_index - indexed_columns
      create_index_on.each { |col| @table.create_index(col, AUTO_INDEX_PREFIX) }

      drop_index_on = auto_indexed_columns - columns_to_index
      drop_index_on.each { |col| @table.drop_index(col, AUTO_INDEX_PREFIX) }
    end

    private

    def indexable_column?(column)
      stats = pg_stats_by_column[column]
      return false unless stats

      # Accept columns with several different values
      common_freqs = stats[:most_common_freqs] || stats[:most_common_elem_freqs]
      if common_freqs.present?
        if common_freqs.last < 0.25
          return true
        end
      else
        # No histrogram, rely on distinct values
        distinct = stats[:n_distinct]
        return true if distinct < 0 || distinct > 4
      end

      # Accept columns with high correlation (values related to physical row order)
      if stats[:correlation].abs > 0.9
        return true
      end

      # Default
      false
    end

    def auto_indices
      indices.select { |i| i[:name].starts_with?(AUTO_INDEX_PREFIX) }
    end

    def indices
      @indices ||= @table.pg_indexes
    end

    def columns_with_widgets
      columns = Set.new
      table_widgets.select { |w| INDEXABLE_WIDGET_TYPES.include?(w.type) }.each do |w|
        columns.add(w.column)
      end
      columns
    end

    def table_widgets
      widgets.select do |w|
        node = w.analysis_node
        node && node.table_source?(@user_table.name)
      end
    end

    def widgets
      @user_table.layers.map(&:widgets).flatten
    end

    def pg_stats_by_column
      @stats ||= get_pg_stats_by_column
    end

    def get_pg_stats_by_column
      @table.update_table_pg_stats
      stats = @table.pg_stats
      stats.map { |s| { s[:attname] => s } }.reduce(:merge)
    end
  end
end
