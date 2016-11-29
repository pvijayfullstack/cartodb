# encoding utf-8

class Carto::Storage::S3
  def self.instance_if_enabled
    s3 = Carto::Storage::S3.new
    s3 if s3.config.present?
  end

  def initailize
    AWS::config(config) if config.present
  end

  def config
    @config ||= Cartodb.config.fetch(:aws, 's3')
  end

  private

  def bucket(bucket_name)
    AWS::S3.new.buckets[bucket_name]
  end
end
