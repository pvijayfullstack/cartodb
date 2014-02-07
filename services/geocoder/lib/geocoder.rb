# encoding: utf-8
require 'typhoeus'
require 'nokogiri'
require 'csv'
require 'json'
require 'open3'
require 'uuidtools'

module CartoDB
  class Geocoder
    BATCH_FILES_OVER = 1100 # Use Here Batch Geocoder API with tables over x rows
    
    # Options for the csv upload endpoint of the Batch Geocoder API
    UPLOAD_OPTIONS = {
      action: 'run',
      indelim: ',',
      outdelim: ',',
      header: false,
      outputCombined: false,
      outcols: "displayLatitude,displayLongitude"
    }

    # Default options for the regular Geocoder API
    GEOCODER_OPTIONS = { 
      gen: 4, 
      housenumber: 8, 
      jsonattributes: 1, 
      language: 'en-US', 
      maxresults: 1
    }

    attr_reader   :base_url, :request_id, :app_id, :token, :mailto,
                  :status, :processed_rows, :total_rows, :dir,
                  :non_batch_base_url

    attr_accessor :input_file

    def initialize(arguments)
      @input_file         = arguments[:input_file]
      @base_url           = arguments[:base_url]
      @non_batch_base_url = arguments[:non_batch_base_url]
      @request_id         = arguments[:request_id]
      @app_id             = arguments.fetch(:app_id)
      @token              = arguments.fetch(:token)
      @mailto             = arguments.fetch(:mailto)
      @force_batch        = arguments[:force_batch] || false
      @dir                = arguments[:dir] || Dir.mktmpdir
    end # initialize

    def use_batch_process?
      @force_batch || input_rows > BATCH_FILES_OVER
    end

    def input_rows
      stdout, stderr, status  = Open3.capture3('wc', '-l', input_file)
      stdout.to_i
    rescue => e
      0
    end

    def upload
      return run_non_batched unless use_batch_process?
      response = Typhoeus.post(
        api_url(UPLOAD_OPTIONS),
        body: File.open(input_file,"r").read,
        headers: { "Content-Type" => "text/plain" }
      )
      handle_api_error(response)
      @request_id = extract_response_field(response.body)
    end # upload

    def cancel
      return unless use_batch_process?
      response = Typhoeus.put api_url(action: 'cancel')
      handle_api_error(response)
      @status         = extract_response_field(response.body, '//Response/Status')
      @processed_rows = extract_response_field(response.body, '//Response/ProcessedCount')
      @total_rows     = extract_response_field(response.body, '//Response/TotalCount')
    end # cancel

    def delete
      return unless use_batch_process?
      response = Typhoeus.delete api_url({})
      handle_api_error(response)
      @status         = extract_response_field(response.body, '//Response/Status')
      @processed_rows = extract_response_field(response.body, '//Response/ProcessedCount')
      @total_rows     = extract_response_field(response.body, '//Response/TotalCount')
    end # cancel

    def update_status
      return unless use_batch_process?
      response = Typhoeus.get api_url(action: 'status')
      handle_api_error(response)
      @status         = extract_response_field(response.body, '//Response/Status')
      @processed_rows = extract_response_field(response.body, '//Response/ProcessedCount')
      @total_rows     = extract_response_field(response.body, '//Response/TotalCount')
    end # update_status

    def result
      return @result unless @result.nil?
      results_filename = File.join(dir, "#{request_id}.zip")
      system('wget', '-nv', '-E', '-O', results_filename, api_url({}, 'result'))
      @result = Dir[File.join(dir, '*')][0]
    end # results

    def run_non_batched
      @result = File.join(dir, 'generated_csv_out.txt')
      @status = 'running'
      @total_rows = input_rows
      @processed_rows = 0
      csv = ::CSV.open(@result, "wb")
      ::CSV.foreach(input_file, headers: true) do |row|
        @processed_rows = @processed_rows + 1
        latitude, longitude = geocode_text(row["searchtext"])
        next if latitude == "" || latitude == nil
        csv << [row["searchtext"], 1, 1, latitude, longitude]
      end
      csv.close
      @status = 'completed'
      @request_id = UUIDTools::UUID.timestamp_create.to_s.gsub('-', '')
    end # run_non_batched

    def geocode_text(text)
      options = GEOCODER_OPTIONS.merge(searchtext: text, app_id: app_id, app_code: token)
      url = "#{non_batch_base_url}?#{URI.encode_www_form(options)}"
      response =  ::JSON.parse(Typhoeus.get(url).body.to_s)["response"]
      position = response["view"][0]["result"][0]["location"]["displayPosition"]
      return position["latitude"], position["longitude"]
    rescue => e
      [nil, nil]
    end

    def api_url(arguments, extra_components = nil)
      arguments.merge!(app_id: app_id, token: token, mailto: mailto)
      components = [base_url]
      components << request_id unless request_id.nil?
      components << extra_components unless extra_components.nil?
      components << '?' + URI.encode_www_form(arguments)
      components.join('/')
    end # api_url

    def extract_response_field(response, query = '//Response/MetaInfo/RequestId')
      Nokogiri::XML(response).xpath("#{query}").first.content
    rescue NoMethodError => e
      nil
    end # extract_response_field

    def handle_api_error(response)
      raise "Geocoding API communication failure: #{extract_response_field(response.body, '//Details')}" if response.code != 200
    end # handle_api_errpr

  end # Geocoder
end # CartoDB
