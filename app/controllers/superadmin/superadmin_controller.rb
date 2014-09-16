class Superadmin::SuperadminController < ActionController::Base
  include SslRequirement
  before_filter :authenticate

  protected

  def authenticate
    return true if authenticated?(CartoDB.extract_subdomain(request)) && current_user.admin
    #return true if Rails.env.development? || authenticated?(CartoDB.extract_subdomain(request)) && current_user.admin
    debugger
    authenticate_or_request_with_http_basic do |username, password|
      username == Cartodb.config[:superadmin]["username"] && password == Cartodb.config[:superadmin]["password"]
    end
  end

  def current_user
    super(CartoDB.extract_subdomain(request))
  end
end
