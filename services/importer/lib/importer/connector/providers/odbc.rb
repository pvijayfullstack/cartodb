# encoding: utf-8

require_relative './base'

module CartoDB
  module Importer2
    class Connector

      # Base class for ODBC-based providers using odbc_fdw
      #
      # Requirements:
      #   * odbc_fdw extension must be installed in the user database
      #
      # Parameters: except for connection, these parameters correspond to options of odbc_fdw which are not connection
      # attributes (odbc_ prefixed options).
      #   * connection: connection attributes; the content is defined by derived classes and will be used
      #     to generate the odbc_ options of odbc_fdw.
      #   * schema: schema name of the remote schema
      #   * table: name of the remote table to import (if no sql_query is given)
      #     and/or local name of the imported result table
      #   * sql_query (optional): SQL code to be executed remotely to produce the dataset to be imported.
      #     If missing, schema.table will be imported.
      #   * sql_count (optional): SQL code to be executed remotely to compute the number of rows of the dataset
      #     to be imported. This shouldn't be needed in general, but could be needed depending on the SQL dialect
      #     that the driver supports.
      #   * encoding (optional): character encoding used by the external database; default is UTF-8.
      #     The encoding names accepted are those accepted by PostgreSQL.
      #
      class OdbcProvider < Provider

        def initialize(params)
          super
          @columns = @params[:columns]
          @columns = @columns.split(',').map(&:strip) if @columns
          @connection = Parameters.new(
            @params[:connection],
            required: required_connection_attributes.keys,
            optional: optional_connection_attributes.keys
          )
        end

        def errors
          super + @connection.errors(parameters_term: 'connection parameters')
        end

        REQUIRED_OPTIONS = %I(table connection).freeze
        OPTIONAL_OPTIONS = %I(schema sql_query sql_count encoding columns).freeze

        def optional_parameters
          OPTIONAL_OPTIONS
        end

        def required_parameters
          REQUIRED_OPTIONS
        end

        # Required connection attributes: { name: :internal_name }
        # The :internal_name is what is passed to the driver (through odbc_fdw 'odbc_' options)
        # The :name is the case-insensitive parameter received here trhough the API
        # This can be redefined as needed in derived classes.
        def required_connection_attributes
          {}
        end

        # Connection attributes that are optional: { name: { internal_name: default_value } }
        # Those with non-nil default values will always be set.
        # name/internal_name as in `required_connection_attributes`
        # This can be redefined as needed in derived classes.
        def optional_connection_attributes
          {}
        end

        # Connection attributes with fixed values: { internal_name: value }
        # which are always passed to the driver
        # This can be redefined as needed in derived classes.
        def fixed_connection_attributes
          {}
        end

        def table_name
          @params[:table]
        end

        def remote_schema_name
          schema = @params[:schema]
          schema = 'public' if schema.blank?
          schema
        end

        def create_server_command(server_name)
          fdw_create_server 'odbc_fdw', server_name, server_options
        end

        def create_usermap_command(server_name, username)
          fdw_create_usermap server_name, username, user_options
        end

        def create_foreign_table_command(server_name, foreign_table_schema, foreign_table_name, foreign_prefix, username)
          cmds = []
          if @columns.present?
            cmds << fdw_create_foreign_table(server_name, foreign_table_schema, foreign_table_name, @columns, table_options)
          else
            options = table_options.merge(prefix: foreign_prefix)
            cmds << fdw_import_foreign_schema(server_name, remote_schema_name, foreign_table_schema, options)
          end
          cmds << fdw_grant_select(foreign_table_schema, foreign_table_name, username)
          cmds.join "\n"
        end

        def features_information
          {
            "list_tables": true,
            "list_databases": false,
            "sql_queries": true
          }
        end

        def parameters_information
          info = super
          required_connection_attributes.keys.each do |name|
            # TODO: description = load template for parameter name of @provider.name
            info[name.to_s] = {
              required: true,
              connection: true
            }
          end
          optional_connection_attributes.keys.each do |name|
            # TODO: description = load template for parameter name of @provider.name
            info[name.to_s] = {
              required: false,
              connection: true
            }
          end
          info
        end

        private

        def attribute_name_map
          optionals = Hash[optional_connection_attributes.map { |k, v| [k.to_s, v.keys.first.to_s] }]
          stringified_required_attrs = Hash[required_connection_attributes.map { |k, v| [k.to_s, v.to_s] }]
          stringified_required_attrs.merge optionals
        end

        def connection_attributes
          # Extract the connection attributes from the @params
          attribute_names = required_connection_attributes.keys + optional_connection_attributes.keys
          attributes = @connection.slice(*attribute_names)

          # Apply non-nil default values
          non_nil_defaults = optional_connection_attributes.reject { |_k, v| v.values.first.nil? }
          attributes.reverse_merge! Hash[non_nil_defaults.map { |k, v| [k.to_s, v.values.first] }]

          # Map attribute names to internal (driver) attributes
          attributes = attributes.map { |k, v| [attribute_name_map[k.to_s.downcase] || k, v] }

          # Set fixed attribute values
          attributes.merge! fixed_connection_attributes

          attributes
        end

        def non_connection_parameters
          @params.slice(*(REQUIRED_OPTIONS + OPTIONAL_OPTIONS - %I(columns connection)))
        end

        SERVER_OPTIONS = %w(dsn driver host server address port database).freeze
        USER_OPTIONS   = %w(uid pwd user username password).freeze

        def connection_options(parameters)
          # Prefix option names with "odbc_"
          # Quote values that contain semicolons (the ODBC connection string pair separator)
          parameters.map { |option_name, option_value| ["odbc_#{option_name}", quoted_value(option_value)] }
        end

        def quoted_value(value)
          value = value.to_s
          if value.to_s.include?(';') && !value.to_s.include?('}')
            "{#{value}}"
          else
            value
          end
        end

        def server_options
          connection_options(connection_attributes.slice(*SERVER_OPTIONS)).parameters
        end

        def user_options
          connection_options(connection_attributes.slice(*USER_OPTIONS)).parameters
        end

        def table_options
          params = connection_options connection_attributes.except(*(SERVER_OPTIONS + USER_OPTIONS))
          params.merge(non_connection_parameters).parameters
        end

      end

    end
  end
end
