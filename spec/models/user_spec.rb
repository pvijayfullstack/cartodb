# coding: UTF-8

require 'spec_helper'

describe User do
  
  it "should set up a user after create" do
    user = new_user
    user.save
    user.reload
    user.should_not be_new
    user.in_database.test_connection.should == true
    user.database_name.should_not be_nil
  end

  it "should have a crypted password" do
    user = create_user :email => 'admin@example.com', :password => 'admin123'
    user.crypted_password.should_not be_blank
    user.crypted_password.should_not == 'admin123'
  end

  it "should authenticate if given email and password are correct" do
    user = create_user :email => 'admin@example.com', :password => 'admin123'
    User.authenticate('admin@example.com', 'admin123').should == user
    User.authenticate('admin@example.com', 'admin321').should be_nil
    User.authenticate('', '').should be_nil
  end
  
  it "should authenticate with case-insensitive email and username" do
    user = create_user :email => 'user@example.com', :username => "user", :password => 'user123'
    User.authenticate('user@example.com', 'user123').should == user
    User.authenticate('UsEr@eXaMpLe.Com', 'user123').should == user
    User.authenticate('user', 'user123').should == user
    User.authenticate('USER', 'user123').should == user
  end
  
  it "should only allow legal usernames" do
    illegal_usernames = %w(si$mon 'sergio estella' j@vi sergio£££ simon_tokumine simon.tokumine SIMON Simon)
    legal_usernames = %w(simon javier-de-la-torre sergio-leiva sergio99)
    user = create_user :email => 'user@example.com', :username => "user", :password => 'user123'
    
    illegal_usernames.each do |name|
      user.username = name
      user.valid?.should be_false
      user.errors[:username].should be_present
    end
    
    legal_usernames.each do |name|
      user.username = name      
      user.valid?.should be_true
      user.errors[:username].should be_blank
    end
  end

  it "should validate that password is present if record is new and crypted_password or salt are blank" do
    user = User.new
    user.username = "admin"
    user.email = "admin@example.com"
    
    user.valid?.should be_false
    user.errors[:password].should be_present
    
    another_user = new_user(user.values.merge(:password => "admin123"))
    user.crypted_password = another_user.crypted_password
    user.salt = another_user.salt
    user.valid?.should be_true
    user.save
    
    # Let's ensure that crypted_password and salt does not change
    user_check = User[user.id]
    user_check.crypted_password.should == another_user.crypted_password
    user_check.salt.should == another_user.salt
    
    user.password = nil
    user.password_confirmation = nil
    user.valid?.should be_true
  end

  it "should have many tables" do
    user = create_user
    user.tables.should be_empty

    create_table :user_id => user.id, :name => 'My first table', :privacy => Table::PUBLIC

    user.reload
    user.tables_count.should == 1
    user.tables.all.should == [Table.first(:user_id => user.id)]
  end

  it "should has his own database, created when the account is created" do
    user = create_user
    user.database_name.should == "cartodb_test_user_#{user.id}_db"
    user.database_username.should == "test_cartodb_user_#{user.id}"
    user.in_database.test_connection.should == true
  end

  it "should create a dabase user that only can read it's own database" do
    user1 = create_user
    user2 = create_user

    connection = ::Sequel.connect(
      ::Rails::Sequel.configuration.environment_for(Rails.env).merge(
        'database' => user1.database_name, :logger => ::Rails.logger,
        'username' => user1.database_username, 'password' => user1.database_password
      )
    )
    connection.test_connection.should == true
    connection.disconnect

    connection = nil
    connection = ::Sequel.connect(
      ::Rails::Sequel.configuration.environment_for(Rails.env).merge(
        'database' => user2.database_name, :logger => ::Rails.logger,
        'username' => user1.database_username, 'password' => user1.database_password
      )
    )
    begin
      connection.test_connection
      true.should_not be_true
    rescue
      true.should be_true
    ensure
      connection.disconnect
    end

    connection = ::Sequel.connect(
      ::Rails::Sequel.configuration.environment_for(Rails.env).merge(
        'database' => user2.database_name, :logger => ::Rails.logger,
        'username' => user2.database_username, 'password' => user2.database_password
      )
    )
    connection.test_connection.should == true
    connection.disconnect

    connection = ::Sequel.connect(
      ::Rails::Sequel.configuration.environment_for(Rails.env).merge(
        'database' => user1.database_name, :logger => ::Rails.logger,
        'username' => user2.database_username, 'password' => user2.database_password
      )
    )
    begin
      connection.test_connection
      true.should_not be_true
    rescue
      true.should be_true
    ensure
      connection.disconnect
    end
  end

  it "should run valid queries against his database" do
    user = create_user
    table = new_table(:user_id => user.id)
    table.import_from_file = "#{Rails.root}/db/fake_data/import_csv_1.csv"
    table.save

    query_result = user.run_query("select * from import_csv_1 where family='Polynoidae' limit 10")
    query_result[:time].should_not be_blank
    query_result[:time].to_s.match(/^\d+\.\d+$/).should be_true
    query_result[:total_rows].should == 2
    # TODO
    # query_result[:columns].should ==  [
    #   [:cartodb_id, "number"], [:id, "number"], [:name_of_species, "string"], [:kingdom, "string"], [:family, "string"],
    #   [:lat, "number", "latitude"], [:lon, "number", "longitude"], [:views, "number"], [:created_at, "date"], [:updated_at, "date"]
    # ]
    query_result[:rows][0][:name_of_species].should == "Barrukia cristata"
    query_result[:rows][1][:name_of_species].should == "Eulagisca gigantea"

    query_result = user.run_query("update import_csv_1 set family='polynoidae' where family='Polynoidae'")
    query_result = user.run_query("select * from import_csv_1 where family='Polynoidae' limit 10")
    query_result[:total_rows].should == 0
    query_result = user.run_query("select * from import_csv_1 where family='polynoidae' limit 10")
    query_result[:total_rows].should == 2

    table2 = new_table :name => 'twitts'
    table2.user_id = user.id
    table2.import_from_file = "#{Rails.root}/db/fake_data/twitters.csv"
    table2.save

    # query_result = user.run_query("select antantaric_species.family as fam, twitts.login as login from antantaric_species, twitts where family='Polynoidae' limit 10")
    # query_result[:total_rows].should == 10
    # query_result[:columns].should == [:fam, :login]
    # query_result[:columns].should ==  [
    #   [:fam, "text"], [:login, "text"]
    # ]
    #
    # query_result[:rows][0].should == { :fam=>"Polynoidae", :login=>"vzlaturistica " }
    #
    # query_result = user.run_query("select count(*) from antantaric_species where family='Polynoidae' ")
    # query_result[:time].should_not be_blank
    # query_result[:time].to_s.match(/^\d+\.\d+$/).should be_true
    # query_result[:total_rows].should == 1
    # query_result[:columns].should ==  [
    #   [:count, "number"]
    # ]
    # query_result[:rows][0].should == {:count => 2}
  end

  it "should raise errors when running invalid queries against his database" do
    user = create_user
    table = new_table
    table.user_id = user.id
    table.import_from_file = "#{Rails.root}/db/fake_data/import_csv_1.csv"
    table.save

    lambda {
      user.run_query("selectttt * from import_csv_1 where family='Polynoidae' limit 10")
    }.should raise_error(CartoDB::ErrorRunningQuery)
  end

  it "can have different keys for accessing via JSONP API requests" do
    user = create_user
    lambda {
      user.create_key ""
    }.should raise_error
    key = user.create_key "mymashup.com"
    api_key = APIKey.filter(:user_id => user.id, :domain => 'http://mymashup.com').first
    api_key.api_key.should == key.api_key
  end

  it "should create a client_application for each user" do
    user = create_user
    user.client_application.should_not be_nil
  end

  it "should reset its client application" do
    user = create_user
    old_key = user.client_application.key

    user.reset_client_application!
    user.reload

    user.client_application.key.should_not == old_key
  end
  
  it "should return the result from the last select query if multiple selects" do
    user = create_user
    table = new_table(:user_id => user.id)
    table.user_id = user.id
    table.import_from_file = "#{Rails.root}/db/fake_data/import_csv_1.csv"
    table.save

    query_result = user.run_query("select * from import_csv_1 where family='Polynoidae' limit 1; select * from import_csv_1 where family='Polynoidae' limit 10")
    query_result[:time].should_not be_blank
    query_result[:time].to_s.match(/^\d+\.\d+$/).should be_true
    query_result[:total_rows].should == 2    
    query_result[:rows][0][:name_of_species].should == "Barrukia cristata"
    query_result[:rows][1][:name_of_species].should == "Eulagisca gigantea"
  end

  it "should allow multiple queries in the format: insert_query; select_query" do
    user = create_user
    table = new_table(:user_id => user.id)
    table.user_id = user.id
    table.import_from_file = "#{Rails.root}/db/fake_data/import_csv_1.csv"
    table.save

    query_result = user.run_query("insert into import_csv_1 (name_of_species,family) values ('cristata barrukia','Polynoidae'); select * from import_csv_1 where family='Polynoidae' limit 10")
    query_result[:total_rows].should == 3    
    query_result[:rows][0][:name_of_species].should == "Barrukia cristata"
    query_result[:rows][1][:name_of_species].should == "Eulagisca gigantea"
    query_result[:rows][2][:name_of_species].should == "cristata barrukia"
  end
  
  it "should fail with error if table doesn't exist" do
    user = create_user
    lambda {
      user.run_query("select * from wadus")
    }.should raise_error(CartoDB::TableNotExists)
  end
  
  it "should have a method that generates users redis users_metadata key" do
    user = create_user
    user.key.should == "rails:users:#{user.username}"
  end  
  
  it "should be able to store the users id and database name in redis" do
    user = create_user
    
    user.save_metadata.should be_true    
    $users_metadata.HGET(user.key, 'id').should == user.id.to_s
    $users_metadata.HGET(user.key, 'database_name').should == user.database_name
  end
  
  it "should store it's metadata automatically after creation" do
    user = create_user
    
    $users_metadata.HGET(user.key, 'id').should == user.id.to_s
    $users_metadata.HGET(user.key, 'database_name').should == user.database_name
  end
  
end
