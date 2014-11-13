# encoding: utf-8

require 'ipaddr'

module CartoDB
  module Importer2
    class ContentGuesser

      COUNTRIES_QUERY = 'SELECT synonyms FROM country_decoder'
      MINIMUM_ENTROPY = 0.9

      def initialize(db, table_name, schema, options)
        @db         = db
        @table_name = table_name
        @schema     = schema
        @options    = options
      end

      def enabled?
        @options[:guessing][:enabled] rescue false
      end

      def country_column
        return nil if not enabled?
        columns.each do |column|
          return column[:column_name] if is_country_column? column
        end
        nil
      end

      def ip_column
        return nil if not enabled?
        columns.each do |column|
          return column[:column_name] if is_ip_column? column
        end
        nil
      end

      def columns
        @columns ||= @db[%Q(
          SELECT column_name, data_type
          FROM information_schema.columns
          WHERE table_name = '#{@table_name}' AND table_schema = '#{@schema}'
        )]
      end

      def is_country_column?(column)
        return false unless is_text_type? column
        return false unless metric_entropy(column) > MINIMUM_ENTROPY
        return country_proportion(column) > threshold
      end

      def is_ip_column?(column)
        return false unless is_text_type? column
        return false unless metric_entropy(column) > MINIMUM_ENTROPY
        return ip_proportion(column) > threshold
      end


      # See http://en.wikipedia.org/wiki/Entropy_(information_theory)
      # See http://www.shannonentropy.netmark.pl/
      #
      # Returns 0.0 if all elements in the column are repeated
      # Returns 1.0 if all elements in the column are different
      def metric_entropy(column)
        shannon_entropy(column) / Math.log(sample.count)
      end

      def shannon_entropy(column)
        sum = 0.0
        frequencies(column).each { |freq| sum += (freq * Math.log(freq)) }
        return -sum
      end

      # Returns an array with the relative frequencies of the elements of that column
      def frequencies(column)
        frequency_table = {}
        column_name_sym = column[:column_name].to_sym
        sample.each do |row|
          elem = row[column_name_sym]
          frequency_table[elem] += 1 rescue frequency_table[elem] = 1
        end
        length = sample.count.to_f
        frequency_table.map { |key, value| value / length }
      end

      def country_proportion(column)
        column_name_sym = column[:column_name].to_sym
        matches = sample.count { |row| countries.include? row[column_name_sym].downcase }
        matches.to_f / sample.count
      end

      def ip_proportion(column)
        column_name_sym = column[:column_name].to_sym
        matches = sample.count { |row| is_ip(row[column_name_sym]) }
        matches.to_f / sample.count
      end

      def is_ip(str)
        (IPAddr.new(str) && true) rescue false
      end


      def threshold
        @options[:guessing][:threshold]
      end

      def is_text_type? column
        ['character varying', 'varchar', 'text'].include? column[:data_type]
      end

      def sample
        @sample ||= @db[%Q(
          SELECT * FROM #{qualified_table_name}
          ORDER BY random() LIMIT #{sample_size}
        )].all
      end

      def sample_size
        @options[:guessing][:sample_size]
      end

      def countries
        return @countries if @countries
        @countries = Set.new()
        geocoder_sql_api.fetch(COUNTRIES_QUERY).each do |country|
          @countries.merge country['synonyms']
        end
        @countries
      end

      def geocoder_sql_api
        @geocoder_sql_api ||= CartoDB::SQLApi.new(@options[:geocoder][:internal])
      end

      attr_writer :geocoder_sql_api

      def qualified_table_name
        %Q("#{@schema}"."#{@table_name}")
      end

    end
  end
end
