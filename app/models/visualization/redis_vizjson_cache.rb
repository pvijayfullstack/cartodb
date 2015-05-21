# encoding: utf-8
module CartoDB
  module Visualization
    class RedisVizjsonCache

      # This needs to be changed whenever there're changes in the code that require invalidation of old keys
      VERSION = '1'

      def initialize(redis_cache)
        @redis_cache = redis_cache
      end


      def cached(visualization_id, https_flag=false)
        key = key(visualization_id, https_flag)
        value = @redis_cache.get(key)
        if value.present?
          return JSON.parse(value, symbolize_names: true)
        else
          result = yield
          serialized = JSON.generate(result)
          @redis_cache.setex(key, 24.hours.to_i, serialized)
          return result
        end
      end

      def invalidate(visualization_id)
        @redis_cache.del key(visualization_id)
        @redis_cache.del key(visualization_id, true)
      end

      def key(visualization_id, https_flag=false)
        "visualization:#{visualization_id}:vizjson:#{VERSION}:#{https_flag ? 'https' : 'http'}"
      end

    end
  end
end
