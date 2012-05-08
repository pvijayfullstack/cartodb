Rails.configuration.middleware.use RailsWarden::Manager do |manager|
  manager.default_strategies :password, :api_authentication
  manager.failure_app = SessionsController
end

# Setup Session Serialization
class Warden::SessionSerializer
  def serialize(user)
    user.username
  end

  def deserialize(username)
    User.filter(:username => username).select(:id,:email,:username,:tables_count,:crypted_password,:database_name,:admin, :map_enabled, :quota_in_bytes, :table_quota, :account_type, :private_tables_enabled).first
  end
end

Warden::Strategies.add(:password) do
  def authenticate!
    if params[:email] && params[:password]
      if (user = User.authenticate(params[:email], params[:password])) && user.enabled?
        success!(user)
      else
        fail!
      end
    else
      fail!
    end
  end
end

Warden::Strategies.add(:api_authentication) do
  def authenticate!
    # WARNING: The following code is a modified copy of the oauth10_token method from
    # oauth-plugin-0.4.0.pre4/lib/oauth/controllers/application_controller_methods.rb
    # It also checks token class like does the oauth10_access_token method of that same file
    if ClientApplication.verify_request(request) do |request_proxy|
          @oauth_token = ClientApplication.find_token(request_proxy.token)
          if @oauth_token.respond_to?(:provided_oauth_verifier=)
            @oauth_token.provided_oauth_verifier=request_proxy.oauth_verifier
          end
          # return the token secret and the consumer secret
          [(@oauth_token.nil? ? nil : @oauth_token.secret), (@oauth_token.nil? || @oauth_token.client_application.nil? ? nil : @oauth_token.client_application.secret)]
        end

      if @oauth_token && @oauth_token.is_a?(::AccessToken)
        success!(User.find_with_custom_fields(@oauth_token.user_id)) and return
      end
    end
    throw(:warden)
  end
end

Warden::Manager.after_authentication do |user,auth,opts|
  user.set_map_key
end
