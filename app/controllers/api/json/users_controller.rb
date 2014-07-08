class Api::Json::UsersController < Api::ApplicationController
  skip_before_filter :api_authorization_required, only: [:get_authenticated_users]
  ssl_required :get_authenticated_users

  if Rails.env.production? || Rails.env.staging?
    ssl_required :show
  end

  def show
    user = current_user
    render json: user.data
  end

  def get_authenticated_users
    authenticated_users = request.session.select {|k,v| k.start_with?("warden.user")}.values
    referer = request.env["HTTP_REFERER"]
    referer_match = /https?:\/\/([\w\-\.]+)(:[\d]+)?(\/(u\/([\w\-\.]+)))?/.match(referer)
 
    if referer_match.nil?
      render status: 400
    else
      real_subdomain = referer_match[1].gsub(CartoDB.session_domain, '')
      request_username = referer_match[5]
    end

    # This array is actually a hack. We will only return at most 1 url, but this way is compatible with the old endpoint
    dashboard_urls = []
    dashboard_base_url = ''

    if !authenticated_users.empty?
      # The owner is seeing his own public dashboard
      if authenticated_users.include?(request_username)
        # The user is in a organization
        if request_username != real_subdomain
          dashboard_base_url = CartoDB.base_url(real_subdomain, request_username)
        else
          dashboard_base_url = CartoDB.base_url(request_username)
        end
      # The owner is not seeing his own public dashboard
      else
        # It's a organization user dashboard
        if request_username != real_subdomain 
          # Check if any of the authenticated users belongs to this org
          requested_organization_users = User.select(:username)
                                          .from('users', 'organizations')
                                          .where("organizations.id=users.organization_id and organizations.name='#{real_subdomain}'")
                                          .collect(&:username)
          users_intersection = requested_organization_users && authenticated_users
          # The user is authenticated with a user belonging to the same requested organization dashboard
          if !users_intersection.empty?
            dashboard_base_url = CartoDB.base_url(real_subdomain, users_intersection.first)
          # The user is authenticated with a user not belonging to the requested organization dashboard
          else
            user_belongs_to_organization = CartoDB::UserOrganization.user_belongs_to_organization?(authenticated_users.first)
            if user_belongs_to_organization.nil?
              dashboard_base_url = CartoDB.base_url(authenticated_users.first)
            else
              dashboard_base_url = CartoDB.base_url(user_belongs_to_organization, authenticated_users.first)
            end
          end
        # It's not a organization dashboard
        else
          user_belongs_to_organization = CartoDB::UserOrganization.user_belongs_to_organization?(authenticated_users.first)
          if user_belongs_to_organization.nil?
            dashboard_base_url = CartoDB.base_url(authenticated_users.first)
          else
            dashboard_base_url = CartoDB.base_url(user_belongs_to_organization, authenticated_users.first)
          end
        end
      end
      if !dashboard_base_url.empty?
        dashboard_urls << "#{dashboard_base_url}/dashboard"
      end
    end

    render json: dashboard_urls
  end

end
