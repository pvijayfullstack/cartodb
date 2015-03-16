# encoding: utf-8

module CartoDB
  module NamedMapsWrapper
        class NamedMaps

            def initialize(user_config, tiler_config, vizjson_config = {})
                raise NamedMapsDataError, { 'user' => 'config missing' } if user_config.nil? or user_config.size == 0
                raise NamedMapsDataError, { 'tiler' => 'config missing' } if tiler_config.nil? or tiler_config.size == 0

                @username = user_config[:name]
                @api_key = user_config[:api_key]
                @vizjson_config = vizjson_config
                @verify_cert = tiler_config[:verifycert]
                @verify_host = tiler_config[:verifycert] ? 2 : 0
                domain = "#{@username}.#{tiler_config[:domain]}"
                host_ip = Cartodb.config[:tiler]['internal']['host'].blank? ? domain : Cartodb.config[:tiler]['internal']['host']
                @host = "#{tiler_config[:protocol]}://#{host_ip}:#{tiler_config[:port]}"
                @url = [ @host, 'api', 'v1', 'map', 'named' ].join('/')
                @headers = { 
                  'content-type' => 'application/json',
                  'host' => "#{@username}.#{tiler_config[:domain]}"
                }
            end

            # Create a new named map and return its instance (or nil if couldn't create)
            def create(visualization)
                NamedMap.create_new(visualization, self)
            end

            # Retrieve a list of all named maps
            def all
                response = Typhoeus.get(@url + '?api_key=' + @api_key, {
                    headers: @headers,
                    ssl_verifypeer: @verify_cert,
                    ssl_verifyhost: @verify_host,
                    followlocation: true
                })
                raise HTTPResponseError, "GET:#{response.code} #{response.request.url} #{response.body}" if response.code != 200

                ::JSON.parse(response.response_body)
            end

            # Get a specific named map given it's name
            def get(name)
                raise NamedMapsDataError, { 'name' => 'mising' } if name.nil? or name.length == 0

                response = Typhoeus.get( [@url, name ].join('/') + '?api_key=' + @api_key, {
                    headers: @headers,
                    ssl_verifypeer: @verify_cert,
                    ssl_verifyhost: @verify_host,
                    followlocation: true
                })

                if response.code == 200
                    template_data = ::JSON.parse(response.response_body)
                    if template_data.class == Hash
                        template_data = template_data.deep_symbolize_keys   # Rails 2.x+
                    end
                    NamedMap.new(name, template_data, self)
                elsif response.code == 404
                    # Request ok, template with provided name not found
                    nil
                else
                    raise HTTPResponseError, "GET:#{response.code} #{response.request.url} #{response.body}"
                end
            end

            attr_reader :url, :api_key, :username, :headers, :host, :vizjson_config, :verify_cert, :verify_host

        end
    end
end
