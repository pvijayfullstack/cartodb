# encoding utf-8

module Carto
  class Bolt
    DEFAULT_REDIS_OBJECT = $users_metadata
    DEFAULT_TTL_MS = 10000

    def initialize(bolt_key, redis_object: DEFAULT_REDIS_OBJECT, ttl_ms: DEFAULT_TTL_MS)
      @bolt_key = add_namespace_to_key(bolt_key)
      @redis_object = redis_object
      @ttl_ms = ttl_ms
    end

    def lock
      is_locked = @redis_object.set(@bolt_key, true, px: @ttl_ms, nx: true)

      if block_given?
        begin
          yield is_locked
          !!is_locked
        ensure
          unlock if is_locked
        end
      else
        is_locked
      end
    end

    def unlock
      removed_keys = @redis_object.del(@bolt_key)

      if removed_keys > 1
        CartoDB.notify_error('Removed bolt key was duplicated', bolt_key: @bolt_key, amount: removed_keys)
      end

      removed_keys > 0 ? true : false
    end

    def info
      { ttl_ms: @ttl_ms, bolt_key: @bolt_key }
    end

    protected

    def add_namespace_to_key(key)
      "rails:bolt:#{key}"
    end
  end
end
