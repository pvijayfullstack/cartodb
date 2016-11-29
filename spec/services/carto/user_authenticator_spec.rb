require 'spec_helper_min'
require 'carto/user_authenticator'

describe Carto::UserAuthenticator do
  before(:all) do
    @user_password = 'admin123'
    @user = FactoryGirl.create(:carto_user, password: @user_password)
  end

  after(:all) do
    @user.delete
  end

  class TestAuthenticator
    extend Carto::UserAuthenticator
  end

  it "should authenticate if given email and password are correct" do
    response_user = TestAuthenticator.authenticate(@user.email, @user_password)
    response_user.id.should eq @user.id
    response_user.email.should eq @user.email

    TestAuthenticator.authenticate(@user.email, @user_password + 'no').should be_nil
    TestAuthenticator.authenticate('', '').should be_nil
  end

  it "should authenticate with case-insensitive email and username" do
    response_user = TestAuthenticator.authenticate(@user.email, @user_password)
    response_user.id.should eq @user.id
    response_user.email.should eq @user.email

    response_user_2 = TestAuthenticator.authenticate(@user.email.upcase, @user_password)
    response_user_2.id.should eq @user.id
    response_user_2.email.should eq @user.email

    response_user_3 = TestAuthenticator.authenticate(@user.username, @user_password)
    response_user_3.id.should eq @user.id
    response_user_3.email.should eq @user.email

    response_user_4 = ::User.authenticate(@user.username.upcase, @user_password)
    response_user_4.id.should eq @user.id
    response_user_4.email.should eq @user.email
  end

end
