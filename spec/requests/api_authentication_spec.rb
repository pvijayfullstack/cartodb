require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "API Authentication" do

  before(:each) do
    @user = create_user(:email => "client@example.com", :password => "clientex")
    @oauth_consumer = OAuth::Consumer.new(@user.client_application.key, @user.client_application.secret, {
      :site => "http://testhost.lan", :scheme => :query_string, :http_method => :post
    })
    @access_token = AccessToken.create(:user => @user, :client_application => @user.client_application)
  end
  
  it "should not authorize requests without signature" do
    get "http://vizzuality.testhost.lan/api/v1/tables"
    status.should == 401
  end

  describe "Standard OAuth" do
    
    before(:each) do
      # We need to specify the complete url in both the prepare_oauth_request method call which we use to build a request from which to take the Authorization header
      # and also when making the request otherwise get/post integration test methods will use example.org
      @request_url = "http://vizzuality.testhost.lan/api/v1/tables"
    end
    
    it "should authorize requests properly signed" do
      req = prepare_oauth_request(@oauth_consumer, @request_url, :token => @access_token)
      get @request_url, {}, {"Authorization" => req["Authorization"]}
      status.should == 200
    end

    it "should not authorize requests with wrong signature" do
      req = prepare_oauth_request(@oauth_consumer, @request_url, :token => @access_token)
      get @request_url, {}, {"Authorization" => req["Authorization"].gsub('oauth_signature="','oauth_signature="314')}
      status.should == 401
    end
  end

  describe "xAuth" do
    before(:each) do
      @request_url = "http://vizzuality.testhost.lan/oauth/access_token"
      @xauth_params = { :x_auth_username => @user.email, :x_auth_password => "clientex", :x_auth_mode => 'client_auth' }
    end
    
    it "should not return an access token with invalid xAuth params" do
      @xauth_params.merge!(:x_auth_password => "invalid")
      req = prepare_oauth_request(@oauth_consumer, @request_url, :form_data => @xauth_params)
      
      post @request_url, @xauth_params, {"Authorization" => req["Authorization"]}
      status.should == 401
    end
    
    it "should return access tokens with valid xAuth params" do
      # Not exactly sure why requests come with SERVER_NAME = "example.org"
      req = prepare_oauth_request(@oauth_consumer, @request_url, :form_data => @xauth_params)
      
      post @request_url, @xauth_params, {"Authorization" => req["Authorization"]}
      status.should == 200

      values = response.body.split('&').inject({}) { |h,v| h[v.split("=")[0]] = v.split("=")[1]; h }
      
      new_access_token = OAuth::AccessToken.new(@oauth_consumer, values["oauth_token"], values["oauth_token_secret"])

      tables_uri = "http://vizzuality.testhost.lan/api/v1/tables"
      req = prepare_oauth_request(@oauth_consumer, tables_uri, :token => new_access_token)
      get tables_uri, {}, {"Authorization" => req["Authorization"]}
      status.should == 200
    end
  end
  
end
