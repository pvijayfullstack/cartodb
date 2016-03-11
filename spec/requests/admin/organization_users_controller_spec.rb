# encoding: utf-8

require_relative '../../spec_helper_min'

describe Admin::OrganizationUsersController do
  include_context 'organization with users helper'
  include Rack::Test::Methods
  include Warden::Test::Helpers

  before(:each) do
    host! "#{@organization.name}.localhost.lan"
  end

  let(:username) { 'user-1' }

  let(:user_params) {
    {
      username: username,
      email: 'user-1@org.com',
      password: 'user-1',
      password_confirmation: 'user-1',
      quota_in_bytes: 1000,
      twitter_datasource_enabled: false
    }
  }

  describe 'security' do
    describe '#show' do
      it 'returns 404 for non authorized users' do

        login_as(@org_user_1, scope: @org_user_1.username)

        get organization_users_url(user_domain: @org_user_1.username)
        last_response.status.should == 404
      end
    end
  end

  describe 'owner behaviour' do
    before(:each) do
      login_as(@org_user_owner, scope: @org_user_owner.username)
    end

    describe '#show' do
      it 'returns 200 for organization owner users' do
        get organization_users_url(user_domain: @org_user_owner.username)
        last_response.status.should == 200
      end
    end

    describe '#create' do
      it 'creates users' do
        User.any_instance.expects(:load_common_data).once.returns(true)

        post create_organization_user_url(user_domain: @org_user_owner.username), user: user_params
        last_response.status.should eq 302

        user = Carto::User.find_by_username(user_params[:username])
        user.email.should eq user_params[:email]
        user.quota_in_bytes.should eq user_params[:quota_in_bytes]
        user.twitter_datasource_enabled.should be_nil

        user.destroy
      end
    end

    describe 'existing user operations' do
      before(:each) do
        @existing_user = FactoryGirl.create(:carto_user, organization: @carto_organization)
      end

      describe '#update' do
        after(:each) do
          ::User[@existing_user.id].destroy
        end

        it 'updates users' do
          new_quota = @existing_user.quota_in_bytes * 2
          put update_organization_user_url(user_domain: @org_user_owner.username, id: @existing_user.username),
              user: { quota_in_bytes: new_quota }
          last_response.status.should eq 302

          @existing_user.reload
          @existing_user.quota_in_bytes.should eq new_quota
        end
      end

      describe '#destroy' do
        it 'deletes users' do
          delete delete_organization_user_url(user_domain: @org_user_owner.username, id: @existing_user.username)
          last_response.status.should eq 302

          ::User[@existing_user.id].should be_nil
        end
      end
    end

    describe 'soft limits' do
      before(:each) do
        User.any_instance.stubs(:load_common_data).returns(true)
      end

      def soft_limit_values(value)
        value.respond_to?(:[]) ? value : [value, value, value]
      end

      def update_soft_limits(user, value)
        values = soft_limit_values(value)
        old_limits = [user.soft_geocoding_limit, user.soft_here_isolines_limit, user.soft_twitter_datasource_limit]
        user.soft_geocoding_limit = values[0]
        user.soft_here_isolines_limit = values[1]
        user.soft_twitter_datasource_limit = values[2]
        user.save

        old_limits
      end

      def check_soft_limits(user, value)
        values = soft_limit_values(value)
        user.soft_geocoding_limit.should eq values[0]
        user.soft_here_isolines_limit.should eq values[1]
        user.soft_twitter_datasource_limit.should eq values[2]
      end

      def soft_limits_params(value)
        values = soft_limit_values(value)
        {
          soft_geocoding_limit: values[0],
          soft_here_isolines_limit: values[1],
          soft_twitter_datasource_limit: values[2]
        }
      end

      describe '#create' do
        it 'owner cannot enable soft limits if he has not' do
          old_limits = update_soft_limits(@carto_org_user_owner, false)

          post create_organization_user_url(user_domain: @org_user_owner.username),
               user: user_params.merge(soft_limits_params(true))
          last_response.status.should eq 422

          Carto::User.exists?(username: user_params[:username]).should be_false

          update_soft_limits(@carto_org_user_owner, old_limits)
        end
      end
    end
  end
end
