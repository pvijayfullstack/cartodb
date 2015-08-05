require_dependency 'google_plus_api'
require_dependency 'google_plus_config'

class SignupController < ApplicationController
  include LoginHelper

  layout 'frontend'

  ssl_required :signup, :create

  before_filter :load_organization
  before_filter :initialize_google_plus_config

  def signup
    @user = ::User.new
  end

  def create
    @user = ::User.new_with_organization(@organization)

    google_access_token = [params.fetch(:google_access_token, nil), params.fetch(:google_signup_access_token, nil)].uniq.compact.first
    # Merge both sources (signup and login) in a single param
    params[:google_access_token] = google_access_token

    if google_access_token.present? && @google_plus_config.present?
      # Keep in mind get_user_data can return nil
      user_data = GooglePlusAPI.new.get_user_data(google_access_token)
    end

    if user_data
      user_data.set_values(@user)
      if params[:user] && params[:user][:username].present?
        @user.username = params[:user][:username]
      end
    else
      @user.username = params[:user][:username]
      @user.email = params[:user][:email]
      @user.password = params[:user][:password]
      @user.password_confirmation = params[:user][:password]
    end

    if @user.valid?
      @user_creation = Carto::UserCreation.new_user_signup(@user)
      @user_creation.save
      ::Resque.enqueue(::Resque::UserJobs::Signup::NewUser, @user_creation.id)
      flash.now[:success] = 'User creation in progress'
      render action: 'signup_confirmation'
    else
      flash.now[:error] = 'User not valid'
      render action: 'signup'
    end
  rescue => e
    CartoDB.notify_exception(e, { new_user: @user.inspect })
    flash.now[:error] = e.message
    render action: 'signup'
  end

  private

  def initialize_google_plus_config
    button_color = @organization.nil? || @organization.color.nil? ? nil : organization_color(@organization)
    @google_plus_config = ::GooglePlusConfig.instance(CartoDB, Cartodb.config, '/signup', 'google_access_token', button_color)
  end

  def load_organization
    subdomain = CartoDB.subdomain_from_request(request)
    @organization = ::Organization.where(name: subdomain).first if subdomain
    render_404 and return false unless @organization && @organization.signup_page_enabled
    render 'organization_signup_issue' unless @organization.remaining_seats > 0
  end

end
