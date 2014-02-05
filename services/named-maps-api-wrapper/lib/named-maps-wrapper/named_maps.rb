# encoding: utf-8

module CartoDB
  module NamedMapsWrapper

		class NamedMaps

			def initialize(user_config, tiler_config, vizjson_config = {})
				raise NamedMapsDataError, { 'user' => 'config missing' } if user_config.nil? or user_config.size == 0
				raise NamedMapsDataError, { 'tiler' => 'config missing' } if tiler_config.nil? or tiler_config.size == 0

				@headers = { 'content-type' => 'application/json' }

				@username = user_config[:name]
				@api_key = user_config[:api_key]
				@vizjson_config = vizjson_config

				@host = "#{tiler_config[:protocol]}://#{@username}.#{tiler_config[:domain]}:#{tiler_config[:port]}"
				@url = [ @host, 'tiles', 'template' ].join('/')
			end #initialize

			# Create a new named map and return its instance (or nil if couldn't create)
			def create(visualization)
				NamedMap.create_new(visualization, self)
			end

			# Retrieve a list of all named maps
			def all
				response = Typhoeus.get(@url + "?api_key=" + @api_key, {
					headers: @headers
				})

				raise HTTPResponseError, response.code if response.code != 200

				::JSON.parse(response.response_body)
			end #all

			# Get a specific named map given it's name
			def get(name)
				raise NamedMapsDataError, { 'name' => 'mising' } if name.nil? or name.length == 0

				response = Typhoeus.get( [@url, name ].join('/') + "?api_key=" + @api_key, {
					headers: @headers
				})

				if response.code == 200
					template_data = ::JSON.parse(response.response_body)
					if template_data.class == Hash
						# Rails 2.x+
						template_data = template_data.deep_symbolize_keys
					end
					NamedMap.new(name, template_data, self)
				elsif response.code == 404
					# Request ok, template with provided name not found
					nil
				else
					raise HTTPResponseError, response.code
				end
			end #get

			attr_reader	:url, :api_key, :username, :headers, :host, :vizjson_config

		end #NamedMaps

	end #NamedMapsWrapper
end #CartoDB