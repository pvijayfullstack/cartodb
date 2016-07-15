# encoding: utf-8
require_relative 'aws_configurator'
require_relative 'url_parser'

module DataRepository
  module Filesystem
    module S3
      class Backend
        DEFAULT_URL_TTL = 600

        def initialize(config = {}, bucket = nil)
          AWSConfigurator.new(config).configure
          @connection = AWS::S3.new
          bucket_name = config.fetch(:bucket_name, nil)
          @bucket     = bucket || bucket_from(bucket_name) || default_bucket
        end

        def store(path, data)
          path    = clean_multiple_slashes_from(path)
          object  = object_from(bucket, path)

          object.write(data)
          object.public_url(secure: true).to_s
        end

        def fetch(file_url)
          bucket_name, object_name = UrlParser.new(file_url).parse
          raise_if_dont_match(bucket.name, bucket_name)

          object_from(bucket, object_name)
        end

        def delete(file_url)
          fetch(file_url).delete
        end

        def presigned_url_for(public_url, url_ttl = DEFAULT_URL_TTL)
          fetch(public_url).url_for(:get, expires: url_ttl).to_s
        end

        private

        attr_reader :connection, :bucket

        def default_bucket
          @default_bucket ||= connection.buckets[ENV.fetch('S3_BUCKET')]
        end

        def bucket_from(bucket_name = nil)
          connection.buckets[bucket_name] if bucket_name
        end

        def object_from(bucket, object_name)
          bucket.objects[object_name]
        end

        def raise_if_dont_match(a, b)
          raise(ArgumentError, "URL doesn't match bucket") unless a == b
        end

        def clean_multiple_slashes_from(path)
          path.split('/').delete_if(&:empty?).join('/')
        end
      end # Backend
    end # S3
  end # Filesystem
end # DataRepository
