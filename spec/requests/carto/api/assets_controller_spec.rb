# encoding: utf-8

require_relative '../../../spec_helper'
require_relative '../../../../app/controllers/carto/api/assets_controller'
require_relative '../../../../spec/requests/api/json/assets_controller_shared_examples'

describe Carto::Api::AssetsController do

  it_behaves_like 'assets controllers' do
  end

  before(:all) do
    # Spec the routes so that it uses the new controller. Needed for alternative routes testing
    Rails.application.routes.draw do
      # new controller
      scope :module => 'carto/api', :format => :json do
        get '(/user/:user_domain)(/u/:user_domain)/api/v1_1/users/:user_id/assets'     => 'assets#index',   as: :api_v1_users_assets_index
      end
    end
  end

  after(:all) do
    Rails.application.reload_routes!
  end

end