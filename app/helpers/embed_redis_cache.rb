# encoding: utf-8

class EmbedRedisCache

  # This needs to be changed whenever there're changes in the code that require invalidation of old keys
  VERSION = '1'


  def initialize(redis_cache)
    @redis = redis_cache
  end

  def get(visualization_id)
    key = key(visualization_id)
    value = redis.get(key)
    if value.present?
      return JSON.parse(value, symbolize_names: true)
    else
      return nil
    end
  end

  # Only public and public with link
  def set(visualization_id, response_headers, response_body)
    serialized = JSON.generate({headers: response_headers,
                                body: response_body
                               })
    redis.setex(key(visualization_id), 24.hours.to_i, serialized)
  end

  def invalidate(visualization_id)
    redis.del key(visualization_id)
  end

  def key(visualization_id)
    "visualization:#{visualization_id}:embed:#{VERSION}"
  end


  private

  def redis
    @redis
  end

end
