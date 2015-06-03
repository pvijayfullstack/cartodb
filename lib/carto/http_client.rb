# encoding: utf-8

require 'typhoeus'
require 'socket'

module Carto
  # Wrapper on top of Typhoeus
  class HttpClient

    private_class_method :new

    def self.get(tag, extra_options = {})
      logger = build_logger(tag, extra_options)
      new(logger)
    end

    def self.build_logger(tag, extra_options)
      if extra_options[:log_requests] && ResponseLogger.enabled?
        ResponseLogger.new(tag, Socket.gethostname)
      else
        NullLogger.new()
      end
    end

    # Returns a wrapper to a typhoeus request object
    def request(url, options = {})
      Request.new(@logger, url, options)
    end

    def get(url, options = {})
      perform_request(__method__, url, options)
    end

    def post(url, options = {})
      perform_request(__method__, url, options)
    end

    def head(url, options = {})
      perform_request(__method__, url, options)
    end

    def put(url, options = {})
      perform_request(__method__, url, options)
    end

    def delete(url, options = {})
      perform_request(__method__, url, options)
    end


    private

    def initialize(logger)
      @logger = logger
    end

    def perform_request(method, url, options)
      request = Request.new(@logger, url, options.merge(method: method))
      request.run
    end


    class Request

      def initialize(logger, url, options = {})
        @logger = logger
        @typhoeus_request = Typhoeus::Request.new(url, options)
      end

      def run
        response = @typhoeus_request.run
        @logger.log(response)
        response
      end

      def url
        @typhoeus_request.url
      end

      def options
        @typhoeus_request.options
      end

      def on_headers(&block)
        @typhoeus_request.on_headers(&block)
      end

      def on_body(&block)
        @typhoeus_request.on_body(&block)
      end

      def on_complete(&block)
        @typhoeus_request.on_complete(&block)
      end
    end


    class ResponseLogger

      def self.enabled?
        defined?(Rails) && Rails.respond_to?(:root) && Rails.root.present? && Cartodb.config[:http_client_logs]
      end

      def initialize(tag, hostname)
        @tag = tag
        @hostname = hostname
      end

      def log(response)
        payload = {
          tag: @tag,
          hostname: @hostname,
          method: (response.request.options[:method] || :get).to_s, # the default typhoeus method is :get
          request_url: response.request.url,
          total_time: response.total_time,
          response_code: response.code,
          response_body_size: response.body.nil? ? 0 : response.body.size
        }
        logger.info(payload.to_json)
      end

      def logger
        @@logger ||= Logger.new("#{Rails.root}/log/http_client.log")
      end
    end

    class NullLogger
      def log(response); end
    end


  end
end
