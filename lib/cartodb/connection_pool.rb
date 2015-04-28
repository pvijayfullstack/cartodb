require 'fiber'

module CartoDB
  class ConnectionPool
    
    MAX_POOL_SIZE = 300
    
    def initialize
      @pool = {}
    end

    # Intended only for testing
    def all
      @pool
    end

    def fetch(configuration, &block)
      conn = nil
      if @pool[connection_id(configuration)]
        Rails.logger.debug "[pool] Found a connection for #{connection_id(configuration)} (#{@pool.keys.size})"
        @pool[connection_id(configuration)][:last_accessed] = Time.now
        conn = @pool[connection_id(configuration)][:connection]
      else
        conn = create_new_connection(configuration, &block)
      end
      # This conn may be still broken after 3 tries
      return conn
    end

    def max_pool_size?
      if @pool.size >= MAX_POOL_SIZE
        #close_connections!
        close_oldest_connection!
      end
    end

    def create_new_connection(configuration, &block)
      max_pool_size?
      connection = yield
      @pool[connection_id(configuration)] = { :connection => connection, :last_accessed => Time.now }
      Rails.logger.debug "[pool] Creating a new connection for #{connection_id(configuration)} (#{@pool.keys.size})"
      connection
    end
    
    def close_connections!(db=nil)
      newpool = {}
      @pool.each do |id, conn|
        if ! db || ( id.start_with? "#{db}:" )
          Rails.logger.debug "[pool] Dropping connection #{id}"
          close_connection(conn[:connection], id)
        else
          Rails.logger.debug "[pool] Not dropping connection #{id}"
          newpool[id] = conn
        end
      end
      @pool = newpool
    end
    
    def close_oldest_connection!
      older = nil
      oldest_access = nil
      @pool.each do |connection_id, conn|
        if oldest_access.nil? || oldest_access < conn[:last_accessed]
          oldest_access = conn[:last_accessed]
          older = connection_id
        end
      end
      close_connection(@pool[older][:connection], older)
      @pool.delete(older)
    end
    
    private
    
    def close_connection(connection, id)
      if id.end_with?('sequel')
        connection.disconnect
      else
        connection.disconnect!
      end
    end

    def connection_id(configuration)
      # TODO: Due to migration from Sequel to ActiveRecord, afterwards can be used with only symbols
      host = configuration.fetch(:host, configuration['host'])
      database = configuration.fetch(:database, configuration['database'])
      username = configuration.fetch(:username, configuration['username'])
      orm = configuration.fetch(:orm, 'sequel')
      # don't prepend new fragments at the beggining, see close_connections! logic
      "#{host}:#{database}:#{username}:#{orm}"
    end
  end
end
