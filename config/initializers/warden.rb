Rails.configuration.middleware.use RailsWarden::Manager do |manager|
  manager.default_strategies :password, :api_authentication
  manager.failure_app = SessionsController
end

# Setup Session Serialization
class Warden::SessionSerializer
  def serialize(user)
    user.id
  end

  def deserialize(user_id)
    User.filter(:id => user_id).select(:id,:email,:username,:tables_count,:crypted_password,:database_name,:admin).first
  end
end

Warden::Strategies.add(:password) do
  def authenticate!
    if params[:email] && params[:password]
      if user = User.authenticate(params[:email], params[:password])
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
    if params[:api_key].blank? && request.headers['Authorization'].blank? && params[:oauth_token].blank?
      throw(:warden)
    else
      if params[:api_key]
        if api_key = APIKey[:api_key => params[:api_key]]
          success!(User[api_key.user_id])
          # TODO
          # if api_key.domain == request.host
          #   success!(api_key.user)
          # else
          #   fail!
          # end
        else
          throw(:warden)
        end
      else
        if ClientApplication.verify_request(request) do |request_proxy|
            @oauth_token = ClientApplication.find_token(request_proxy.token)
            throw(:warden) unless @oauth_token
            if @oauth_token.respond_to?(:provided_oauth_verifier=)
              @oauth_token.provided_oauth_verifier = request_proxy.oauth_verifier
            end
          end
        end
        success!(User[@oauth_token.user_id])
      end
    end
  end
end
