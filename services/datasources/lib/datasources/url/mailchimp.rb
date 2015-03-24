# encoding: utf-8

require 'typhoeus'
require 'json'
require 'gibbon'
require 'addressable/uri'
require_relative '../base_oauth'

module CartoDB
  module Datasources
    module Url
      # Note:
      # - MailChimp access tokens don't expire, no need to handle that logic
      class MailChimp < BaseOAuth

        # Required for all datasources
        DATASOURCE_NAME = 'mailchimp'

        AUTHORIZE_URI = 'https://login.mailchimp.com/oauth2/authorize?response_type=code&client_id=%s&redirect_uri=%s'
        ACCESS_TOKEN_URI = 'https://login.mailchimp.com/oauth2/token'
        MAILCHIMP_METADATA_URI = 'https://login.mailchimp.com/oauth2/metadata'

        API_TIMEOUT_SECS = 60

        # Constructor
        # @param config Array
        # [
        #  'api_key'
        #  'timeout_minutes'
        # ]
        # @param user User
        # @throws UninitializedError
        # @throws MissingConfigurationError
        def initialize(config, user)
          super

          raise UninitializedError.new('missing user instance', DATASOURCE_NAME) if user.nil?
          raise MissingConfigurationError.new('missing app_key', DATASOURCE_NAME) unless config.include?('app_key')
          raise MissingConfigurationError.new('missing app_secret', DATASOURCE_NAME) unless config.include?('app_secret')
          raise MissingConfigurationError.new('callback_url'. DATASOURCE_NAME) unless config.include?('callback_url')

          @user = user
          @app_key = config.fetch('app_key')
          @app_secret = config.fetch('app_secret')

          placeholder = CALLBACK_STATE_DATA_PLACEHOLDER.sub('user', @user.username).sub('service', DATASOURCE_NAME)
          @callback_url = "#{config.fetch('callback_url')}?state=#{placeholder}"

          Gibbon::API.timeout = API_TIMEOUT_SECS
          Gibbon::API.throws_exceptions = true
          Gibbon::Export.timeout = API_TIMEOUT_SECS
          Gibbon::Export.throws_exceptions = false

          @access_token = nil
          @api_client = nil
        end

        # Factory method
        # @param config : {}
        # @param user : User
        # @return CartoDB::Datasources::Url::MailChimpLists
        def self.get_new(config, user)
          return new(config, user)
        end

        # If will provide a url to download the resource, or requires calling get_resource()
        # @return bool
        def providers_download_url?
          false
        end

        # Return the url to be displayed or sent the user to to authenticate and get authorization code
        # @param use_callback_flow : bool
        # @return string : URL to navigate to for the authorization flow
        # @throws ExternalServiceError
        def get_auth_url(use_callback_flow=true)
          if use_callback_flow
            AUTHORIZE_URI % [@app_key, Addressable::URI.encode(@callback_url)]
          else
            raise ExternalServiceError.new("This datasource doesn't allows non-callback flows", DATASOURCE_NAME)
          end
        end

        # Validate authorization code and store token
        # @param auth_code : string
        # @return string : Access token
        # @throws ExternalServiceError
        def validate_auth_code(auth_code)
          raise ExternalServiceError.new("This datasource doesn't allows non-callback flows", DATASOURCE_NAME)
        end

        # Validates the authorization callback
        # @param params : mixed
        # @throws AuthError
        def validate_callback(params)
          code = params.fetch('code')
          if code.nil? || code == ''
            raise "Empty callback code"
          end

          token_call_params = {
            grant_type: 'authorization_code',
            client_id: @app_key,
            client_secret: @app_secret,
            code: code,
            redirect_uri: @callback_url
          }

          token_response = Typhoeus.post(ACCESS_TOKEN_URI, http_options(token_call_params, :post))
          unless token_response.code == 200
            raise "Bad token response: #{token_response.body.inspect} (#{token_response.code})"
          end
          token_data = ::JSON.parse(token_response.body)

          partial_access_token = token_data['access_token']

          # Afterwards, must do another call to metadata endpoint to retrieve API details
          # @see https://apidocs.mailchimp.com/oauth2/
          metadata_response = Typhoeus.get(MAILCHIMP_METADATA_URI,http_options({}, :get, {
                                             'Authorization' => "OAuth #{partial_access_token}"}))
          unless metadata_response.code == 200
            raise "Bad metadata response: #{metadata_response.body.inspect} (#{metadata_response.code})"
          end
          metadata_data = ::JSON.parse(metadata_response.body)

          # This specially formed token behaves as an API Key for client calls using API
          @access_token = "#{partial_access_token}-#{metadata_data['dc']}"
        rescue => ex
          raise AuthError.new("validate_callback(#{params.inspect}): #{ex.message}", DATASOURCE_NAME)
        end

        # Set the token
        # @param token string
        # @throws TokenExpiredOrInvalidError
        def token=(token)
          @access_token = token
          @api_client = Gibbon::API.new(@access_token)
        rescue Gibbon::MailChimpError => exception
          raise TokenExpiredOrInvalidError.new("token=() : #{exception.message} (API code: #{exception.code})",
                                               DATASOURCE_NAME)
        rescue => exception
          raise TokenExpiredOrInvalidError.new("token=() : #{exception.inspect}", DATASOURCE_NAME)
        end

        # Retrieve set token
        # @return string | nil
        def token
          @access_token
        end

        # Perform the listing and return results
        # @param filter Array : (Optional) filter to specify which resources to retrieve. Leave empty for all supported.
        # @return [ { :id, :title, :url, :service } ]
        # @throws UninitializedError
        # @throws DataDownloadError
        def get_resources_list(filter=[])
          raise UninitializedError.new('No API client instantiated', DATASOURCE_NAME) unless @api_client.present?

          all_results = []
          offset = 0
          limit = 100
          total = nil

          begin
            response = @api_client.campaigns.list({
                                                start: offset,
                                                limit: limit
                                              })
            errors = response.fetch('errors', [])
            unless errors.empty?
              raise DataDownloadError.new("get_resources_list(): #{errors.inspect}", DATASOURCE_NAME)
            end

            total = response.fetch('total', 0).to_i if total.nil?

            response_data = response.fetch('data', [])
            response_data.each do |item|
              # Skip items without tracking
              all_results.push(format_activity_item_data(item)) if item['tracking']['opens']
            end

            offset += limit
          end while offset < total

          all_results
        rescue Gibbon::MailChimpError => exception
          raise DataDownloadError.new("get_resources_list(): #{exception.message} (API code: #{exception.code}",
                                      DATASOURCE_NAME)
        rescue => exception
          raise DataDownloadError.new("get_resources_list(): #{exception.inspect}", DATASOURCE_NAME)
        end

        # Retrieves a resource and returns its contents
        # @param id string
        # @return mixed
        # @throws UninitializedError
        # @throws DataDownloadError
        def get_resource(id)
          raise UninitializedError.new('No API client instantiated', DATASOURCE_NAME) unless @api_client.present?

          subscribers = []
          contents = ''
          export_api = @api_client.get_exporter

          # 1) Retrieve campaign details
          campaign = get_resource_metadata(id)
          campaign_details = export_api.list({id: campaign[:list_id]})
          campaign = nil

          # 2) Retrieve subscriber activity
          # https://apidocs.mailchimp.com/export/1.0/campaignsubscriberactivity.func.php
          subscribers_activity = export_api.campaign_subscriber_activity({id: id})
          subscribers_activity.each { |line|
            item_data = activity_data_item(line)
            subscribers.push(item_data) if item_data[:opened]
          }
          subscribers_activity = nil

          # 3) Update campaign details with subscriber activity results
          # 4) anonymize data (inside list_json_to_csv)
          campaign_details.each_with_index { |line, index|
            contents << list_json_to_csv(line, subscribers, index == 0)
          }

          contents
        rescue Gibbon::MailChimpError => exception
          raise DataDownloadError.new("get_resource(): #{exception.message} (API code: #{exception.code}",
                                      DATASOURCE_NAME)
        rescue => exception
          raise DataDownloadError.new("get_resource(): #{exception.inspect}", DATASOURCE_NAME)
        end

        # @param id string
        # @return Hash
        # @throws UninitializedError
        # @throws DataDownloadError
        def get_resource_metadata(id)
          raise UninitializedError.new('No API client instantiated', DATASOURCE_NAME) unless @api_client.present?

          item_data = {}

          # No metadata call at API, so just retrieve same info but from specific campaign id
          # https://apidocs.mailchimp.com/api/2.0/campaigns/list.php
          response = @api_client.campaigns.list({ filters: { campaign_id: id } })

          errors = response.fetch('errors', [])
          unless errors.empty?
            raise DataDownloadError.new("get_resources_list(): #{errors.inspect}", DATASOURCE_NAME)
          end
          response_data = response.fetch('data', [])

          response_data.each do |item|
            if item.fetch('id') == id
              item_data = format_activity_item_data(item)
            end
          end

          item_data
        rescue Gibbon::MailChimpError => exception
          raise DataDownloadError.new("get_resource_metadata(): #{exception.message} (API code: #{exception.code}",
                                      DATASOURCE_NAME)
        rescue => exception
          raise DataDownloadError.new("get_resource_metadata(): #{exception.inspect}", DATASOURCE_NAME)
        end

        # Retrieves current filters
        # @return {}
        def filter
          []
        end

        # Sets current filters
        # @param filter_data {}
        def filter=(filter_data=[])
        end

        # Just return datasource name
        # @return string
        def to_s
          DATASOURCE_NAME
        end

        # If this datasource accepts a data import instance
        # @return Boolean
        def persists_state_via_data_import?
          false
        end

        # Stores the data import item instance to use/manipulate it
        # @param value DataImport
        def data_import_item=(value)
          nil
        end

        # Checks if token is still valid or has been revoked
        # @return bool
        # @throws AuthError
        def token_valid?
          raise UninitializedError.new('No API client instantiated', DATASOURCE_NAME) unless @api_client.present?

          # Any call would do, we just want to see if communicates or refuses the token
          # This call is available to all roles
          response = @api_client.users.profile
          # 'errors' only appears in failure scenarios, while 'username' only if went ok
          response.fetch('errors', nil).nil? && !response.fetch('username', nil).nil?
        rescue
          false
        end

        # Revokes current set token
        def revoke_token
          # not supported
        end

        # Sets an error reporting component
        # @param component mixed
        def report_component=(component)
          nil
        end

        private

        def http_options(params={}, method=:get, extra_headers={})
          {
            method:           method,
            params:           method == :get ? params : {},
            body:             method == :post ? params : {},
            followlocation:   true,
            ssl_verifypeer:   false,
            headers:          {
                                'Accept' => 'application/json'
                              }.merge(extra_headers),
            ssl_verifyhost:   0,
            timeout:          60
          }
        end

        # Formats all data to comply with our desired format
        # @param item_data Hash : Single item returned from MailChimp API
        # @return { :id, :title, :url, :service, :size }
        def format_activity_item_data(item_data)
          filename = item_data.fetch('title').gsub(' ', '_')
          {
            id:       item_data.fetch('id'),
            list_id:  item_data.fetch('list_id'),
            title:    "#{item_data.fetch('title')}",
            filename: "#{filename}.csv",
            service:  DATASOURCE_NAME,
            checksum: '',
            member_count: item_data.fetch('emails_sent'),
            size:     NO_CONTENT_SIZE_PROVIDED
          }
        end

        # @see https://apidocs.mailchimp.com/export/1.0/#overview_description
        def activity_json_to_csv(input_fields='[]')
          opened_action = false
          fields = []
          contents = ::JSON.parse(input_fields)
          contents.each { |subject, actions|
            # Anonimize by removing the name and leaving only the email domain
            fields.push("\"#{subject.to_s.gsub("\n", ' ').gsub('"', '""').gsub(/(.*)@/, "")}\"")
            unless actions.length == 0
              actions.each { |action|
                if action["action"] == "open" && !opened_action
                  fields.push("\"#{action["timestamp"]}\"")
                  fields.push(action["ip"].nil? ? '' : "\"#{action["ip"]}\"")
                  opened_action = true
                end
              }
            end
          }
          # Empty action scenario
          unless opened_action
            fields.push("\"\"")
            fields.push("")
          end
          data = fields.join(',')
          data << "\n"
        end

        def activity_data_item(input_fields='[]')
          email = nil
          opened_action = false
          contents = ::JSON.parse(input_fields)
          contents.each { |subject, actions|
            email = subject
            unless actions.length == 0
              actions.each { |action|
                opened_action = true if action["action"] == "open"
              }
            end
          }

          { subject: email, opened: opened_action }
        end

        # @param contents String containing a JSON Hash
        # @param subscribers Array containing a Hash { subject, opened }
        # @param header_row Boolean
        def list_json_to_csv(contents='[]', subscribers=[], header_row=false)
          opened_mail = false
          contents = ::JSON.parse(contents)

          opened_mail = (subscribers.index{ |item| item[:subject] == contents[0] } != nil) unless header_row == 0

          contents.each_with_index { |field, index|
            # Anonymize emails
            if index == 0
              contents[index] = "\"#{field.to_s.gsub("\n", ' ').gsub('"', '""').gsub(/^(.*)@/, "")}\""
            else
              contents[index] = "\"#{field.to_s.gsub("\n", ' ').gsub('"', '""')}\""
            end
          }
          contents.push("\"#{header_row ? 'Opened' : opened_mail.to_s}\"")
          data = contents.join(',')
          data << "\n"
        end

      end
    end
  end
end
