# coding: utf-8

class Admin::ClientApplicationsController < ApplicationController
  ssl_required :oauth, :api_key, :regenerate_api_key, :regenerate_oauth

  before_filter :login_required

  def oauth
    new_dashboard = current_user.has_feature_flag?('new_dashboard')
    view =  new_dashboard ? 'new_oauth' : 'api_key'
    layout = new_dashboard ? 'new_application' : 'application'

    respond_to do |format|
      format.html { render view, layout: layout }
    end
  end

  def api_key
    new_dashboard = current_user.has_feature_flag?('new_dashboard')
    view =  new_dashboard ? 'new_api_key' : 'api_key'
    layout = new_dashboard ? 'new_application' : 'application'

    respond_to do |format|
      format.html { render view, layout: layout }
    end
  end

  def regenerate_api_key
    begin
      current_user.invalidate_varnish_cache
      current_user.update api_key: User.make_token
      flash_message = "Your API key has been successfully generated"
    rescue Errno::ECONNREFUSED => e
      CartoDB::Logger.info "Could not clear varnish cache", "#{e.inspect}"
      if Rails.env.development?
        current_user.set_map_key
        flash_message = "Your API key has been regenerated succesfully but the varnish cache has not been invalidated."
      else
        raise e
      end
    rescue => e
      raise e
    end

    redirect_to CartoDB.url(self, 'api_key_credentials', {type: 'api_key'}, current_user),
                :flash => {:success => "Your API key has been regenerated successfully"}
  end

  def regenerate_oauth
    @client_application = current_user.client_application
    return if request.get?
    current_user.reset_client_application!
    
    new_dashboard = current_user.has_feature_flag?('new_dashboard')
    if new_dashboard
      redirect_to CartoDB.url(self, 'oauth_credentials', {type: 'oauth'}, current_user),
                  :flash => {:success => "Your OAuth credentials have been updated successfully"}
    else
      redirect_to CartoDB.url(self, 'api_key_credentials', {type: 'oauth'}, current_user),
                  :flash => {:success => "Your OAuth credentials have been updated successfully"}
    end 
    
  end

end
