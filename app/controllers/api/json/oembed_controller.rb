
# encoding: utf-8

require 'uri'

class Api::Json::OembedController < Api::ApplicationController
  include CartoDB

  skip_before_filter :api_authorization_required

  # Returns oembed data as required
  def show
    url = params[:url]
    width = params[:maxwidth] || '100%'
    height = params[:maxheight] || '520px'
    format = request.query_parameters[:format]
    force_https = true if params[:allow_http].nil?

    raise ActionController::RoutingError.new('Incorrect width') if (width =~ /^[0-9]+(%|px)?$/).nil?
    raise ActionController::RoutingError.new('Incorrect height') if (height =~ /^[0-9]+(%|px)?$/).nil?

    uri = URI.parse(url)

    begin
      uuid = /(\w{8}-\w{4}-\w{4}-\w{4}-\w{12})/.match(uri.path)[0]
    rescue NoMethodError
      raise ActionController::RoutingError.new('UUID not found in URL')
    end

    begin
      viz = CartoDB::Visualization::Member.new(id: uuid).fetch
    rescue KeyError
      name = ''
    else
      name = viz.name
    end
    
    fields = url_fields_from_fragments(url, force_https)

    # build the url using full schema because any visuaization should work with any user
    if fields[:organization_name].nil?
      url = CartoDB.base_url(fields[:username])
    else
      url = CartoDB.base_url(fields[:organization_name], fields[:username])
    end
    url += CartoDB.path(self, 'public_visualizations_embed_map', {id: uuid})

    # force the schema
    if fields[:protocol] == 'https' && !url.include?('https')
      url = url.sub('http', 'https')
    end

    html = "<iframe width='#{width}' height='#{height}' frameborder='0' src='#{url}' allowfullscreen webkitallowfullscreen mozallowfullscreen oallowfullscreen msallowfullscreen></iframe>"

    response_data = {
        :type => 'rich',
        :version => '1.0',
        :width => width,
        :height => height,
        :title => name,
        :html => html,
        :author_name => fields[:username],
        :author_url => fields[:user_profile_url],
        :provider_name => 'CartoDB',
        :provider_url => "#{fields[:protocol]}://www.cartodb.com/"
    }

    if format == 'xml'
      render xml: response_data.to_xml(root: 'oembed')
    else
      render json: response_data.to_json
    end
  end

  private

  def url_fields_from_fragments(url, force_https)
    domain = CartoDB.session_domain
    # @see http://ruby-doc.org/stdlib-1.9.3/libdoc/uri/rdoc/URI.html#method-c-split
    url_fragments = URI.split(url)
    protocol = force_https ? "https" : URI.parse(url).scheme

    data = nil
    unless CartoDB.subdomainless_urls?
      begin
        data = from_url(url_fragments, protocol, domain)
      rescue UrlFRagmentsError
        # URL is subdomainless so do nothing
      end
    end

    # Either subdomains disallowed or url doesn't uses them
    if data.nil?
      data = from_domainless_url(url_fragments, protocol)
    end

    raise UrlFRagmentsError.new("Couldn't extract URL fields") if data.nil?

    {
      organization_name: data[:organization_name],
      username: data[:username],
      user_profile_url: data[:user_profile_url],
      protocol: protocol
    }
  end

  # testuser.cartodb.com || testorg.cartodb.com/u/user
  def from_url(url_fragments, protocol, domain)
    # To ease testing don't request eactly all URI.split params
    raise UrlFRagmentsError.new("Invalid url_fragments parameter") unless url_fragments.length > 5

    subdomain = url_fragments[2].sub(domain, '.').split('.')[0]
    raise UrlFRagmentsError.new("Subdomain not found at url") if subdomain.nil?

    # org-based
    if url_fragments[5][0..2] == "/u/"
      organization_name = subdomain
      username = username_from_url_fragments(url_fragments)
    else
      organization_name = nil
      username = subdomain
    end

    {
      username: username,
      organization_name: organization_name,
      user_profile_url: CartoDB.base_url(subdomain, organization_name.nil? ? nil : username, protocol)
    }
  end

  # https://cartodb.com/u/testuser/...
  def from_domainless_url(url_fragments, protocol)
    # To ease testing don't request eactly all URI.split params
    raise UrlFRagmentsError.new("Invalid url_fragments parameter") unless url_fragments.length > 5

                                                      # url_fragments[5]: Path
    raise UrlFRagmentsError.new("URL needs username specified in the Path") if url_fragments[5][0..2] != "/u/"

    # url_fragments[3]: Host
    port_fragment =
      url_fragments[3].nil? || url_fragments[3] == '' || url_fragments[3].to_i == 80 ? '' : ":#{url_fragments[3]}"

    username = username_from_url_fragments(url_fragments)
    {
      username: username,
      organization_name: nil,
                                        # url_fragments[2]: Host
      user_profile_url: "#{protocol}://#{url_fragments[2]}#{port_fragment}/u/#{username}"
    }
  end

  def username_from_url_fragments(url_fragments)
    path_fragments = url_fragments[5].split('/')
    raise UrlFRagmentsError.new("Username not found at url") if path_fragments.length < 3 || path_fragments[2].length == 0
    path_fragments[2]
  end

end

class UrlFRagmentsError < StandardError

end