namespace :cartodb do
  namespace :db do
    desc <<-DESC
Setup cartodb database and creates a new user from environment variables:
  - ENV['EMAIL']: user e-mail
  - ENV['PASSWORD']: user password
  - ENV['SUBDOMAIN']: user subdomain
DESC
    task :setup => ["rake:db:create", "rake:db:migrate", "cartodb:db:create_publicuser", "cartodb:db:create_admin"] do
      begin
        raise "You should provide a valid e-mail"    if ENV['EMAIL'].blank?
        raise "You should provide a valid password"  if ENV['PASSWORD'].blank?
        raise "You should provide a valid subdomain" if ENV['SUBDOMAIN'].blank?

        u = User.new
        u.email = ENV['EMAIL']
        u.password = ENV['PASSWORD']
        u.password_confirmation = ENV['PASSWORD']
        u.username = ENV['SUBDOMAIN']
        u.save
        if u.new?
          raise u.errors.inspect
        end
      rescue => e
        puts e.inspect
      end
    end
    
    desc "make public and tile users"
    task :create_publicuser => :environment do
      begin
        ::Rails::Sequel.connection.run("CREATE USER #{CartoDB::PUBLIC_DB_USER}")
      rescue
      end
      begin
        ::Rails::Sequel.connection.run("CREATE USER #{CartoDB::TILE_DB_USER}")
      rescue
      end  
    end

    # TODO: remove text bit and just use env
    desc "Create a plain user account"
    task :create_user => :environment do
      begin
        raise "You should provide a valid e-mail"    if ENV['EMAIL'].blank?
        raise "You should provide a valid password"  if ENV['PASSWORD'].blank?
        raise "You should provide a valid subdomain" if ENV['SUBDOMAIN'].blank?

        u = User.new
        u.email = ENV['EMAIL']
        u.password = ENV['PASSWORD']
        u.password_confirmation = ENV['PASSWORD']
        u.username = ENV['SUBDOMAIN']
        u.save
        if u.new?
          raise u.errors.inspect
        end
      rescue => e
        puts e.inspect
      end
    end
    
    # TODO: remove text bit and just use env
    desc "Create an admin account with a password from ENV['ADMIN_PASSWORD'] environment variable"
    task :create_admin => :environment do
      raise "Set ADMIN_PASSWORD environment variable" if ENV['ADMIN_PASSWORD'].blank?
      password = ENV['ADMIN_PASSWORD']
      
      u = User.new
      u.email = "admin@cartodb.com"
      u.password = password
      u.password_confirmation = password
      u.username = "admin"
      u.enabled = true
      u.admin = true
      u.save
      if u.new?
        raise u.errors.inspect
      end
    end
    
    desc "Sets the password of the admin user to the value of a ADMIN_PASSWORD environment variable"
    task :change_admin_password => :environment do
      raise "Set ADMIN_PASSWORD environment variable" if ENV['ADMIN_PASSWORD'].blank?
      password = ENV['ADMIN_PASSWORD']
      
      u = User.filter(:username => "admin").first
      u.password = ENV['ADMIN_PASSWORD']
      u.password_confirmation = ENV['ADMIN_PASSWORD']
      if !u.save
        raise u.errors.inspect
      end
    end

    desc "Set the password of the user in the USERNAME environment variable to the value of the USER_PASSWORD environment variable"
    task :change_user_password => :environment do
      raise "Set USER_NAME environment variable" if ENV['USER_NAME'].blank?
      raise "Set USER_PASSWORD environment variable" if ENV['USER_PASSWORD'].blank?
      password = ENV['USER_PASSWORD']

      users = User.filter(:username => ENV['USER_NAME']).all
      if users.empty?
        raise "User doesn't exist"
      else
        u = users.first
        u.password = password
        u.password_confirmation = password
        if !u.save
          rais u.errors.inspect
        else
          puts "Password changed"
        end
      end
    end
  end
end
