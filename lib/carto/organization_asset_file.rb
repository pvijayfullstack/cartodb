# encoding: utf-8

require 'carto/storage'

module Carto
  class OrganizationAssetFile
    DEFAULT_LOCATION = 'organization_assets'.freeze

    def self.location
      Cartodb.get_config_if_present(:assets, 'organization', 'bucket') ||
        Cartodb.get_config_if_present(:assets, 'organization', 'location') ||
        DEFAULT_LOCATION
    end

    DEFAULT_MAX_SIZE_IN_BYTES = 1_048_576 # 1 MB

    def self.max_size_in_bytes
      Cartodb.get_config_if_present(:assets, 'organizations', 'max_size_in_bytes') ||
        DEFAULT_MAX_SIZE_IN_BYTES
    end

    attr_reader :url, :organization, :errors

    def initialize(organization, url)
      @organization = organization
      @url = url
      @errors = Hash.new
    end

    def public_url
      if valid?
        Storage.instance.upload(self.class.location, organization.id, file)
      end
    end

    def valid?
      file && errors.empty?
    end

    def file
      @file ||= fetch_file
    end

    private

    def fetch_file
      temp_file = Tempfile.new(Time.now.utc)

      max_size_in_bytes = self.class.max_size_in_bytes
      read = IO.copy_stream(open(url), temp_file, max_size_in_bytes + 1)

      if read > max_size_in_bytes
        errors[:file] = "too big (> #{max_size_in_bytes})"
      end
    ensure
      temp_file.close

      temp_file
    end
  end
end
