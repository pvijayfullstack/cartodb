# encoding: utf-8
require 'sequel'
require 'uuidtools'

module DataRepository
  module Backend
    class Sequel
      PAGE          = 1
      PER_PAGE      = 300
      ARRAY_RE      = %r{\[.*\]}

      def initialize(db, relation=nil)
        @db         = db
        @relation   = relation.to_sym
        ::Sequel.extension(:pagination)
        ::Sequel.extension(:connection_validator)
        @db.extension :pg_array if postgres?(@db)
      end #initialize

      def collection(filters={}, available_filters=[])
        apply_filters(db[relation], filters, available_filters)
      end #collection

      def store(key, data={})
        naive_upsert_exposed_to_race_conditions(data)
      end #store

      def fetch(key)
        parse( db[relation].where(id: key).first )
      end #fetch

      def delete(key)
        db[relation].where(id: key).delete
      end #delete

      def next_id
        UUIDTools::UUID.timestamp_create
      end #next_id

      def apply_filters(dataset, filters={}, available_filters=[])
        return dataset if filters.nil? || filters.empty?
        available_filters   = symbolize_elements(available_filters)

        filters = symbolize_keys(filters).select { |key, value|
          available_filters.include?(key)
        } unless available_filters.empty?

        dataset.where(filters)
      end

      def paginate(dataset, filter={}, record_count=nil)
        page, per_page = pagination_params_from(filter)
        dataset.paginate(page, per_page, record_count)
      end

      private

      attr_reader :relation, :db

      def naive_upsert_exposed_to_race_conditions(data={})
        data = send("serialize_for_#{backend_type}", data)
        insert(data) unless update(data)
      end #naive_upsert_exposed_to_race_conditions

      def insert(data={})
        db[relation].insert(data)
      end #insert

      def update(data={})
        db[relation].where(id: data.fetch(:id)).update(data) != 0
      end #update

      def serialize_for_postgres(data)
        Hash[
          data.map { |key, value|
            value = value.pg_array if value.is_a?(Array) && !value.empty? 
            [key, value]
          }
        ]
      end #serialize_for_postgres

      def serialize_for_other_database(data={})
        Hash[
          data.map { |key, value|
            value = value.to_s if value.is_a?(Array)
            [key, value]
          }
        ]
      end #serialize_for_other_database

      def backend_type
        return :postgres if postgres?(db)
        return :other_database
      end #backend_type

      def postgres?(db)
        db.database_type == :postgres
      end #postgres?

      def parse(attributes={})
        return unless attributes
        return attributes if postgres?(db)

        Hash[
          attributes.map do |key, value|
            value = JSON.parse(value) if value =~ ARRAY_RE
            [key, value]
          end
        ]
      end #parse

      def symbolize_elements(array=[])
        array.map { |k| k.to_sym}
      end #symbolize_elements

      def symbolize_keys(hash={})
        Hash[ hash.map { |k, v| [k.to_sym, v] } ]
      end #symbolize_keys

      def pagination_params_from(filter)
        page      = (filter.delete(:page)      || PAGE).to_i
        per_page  = (filter.delete(:per_page)  || PER_PAGE).to_i

        [page, per_page]
      end #pagination_params_from
    end # Sequel
  end # Backend
end # DataRepository

