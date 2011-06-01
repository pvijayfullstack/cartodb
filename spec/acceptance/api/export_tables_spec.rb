# coding: UTF-8

require File.expand_path(File.dirname(__FILE__) + '/../acceptance_helper')

feature "API 1.0 tables export" do

  background do
    Capybara.current_driver = :rack_test
    @user = create_user
    login_as @user
    
    @table = new_table
    @table.import_from_file = Rack::Test::UploadedFile.new("#{Rails.root}/db/fake_data/import_csv_1.csv", "text/csv")
    @table.user_id = @user.id
    @table.name = "antantaric_species"
    @table.save
  end

  scenario "Get table in CSV format" do
    response = get "#{api_table_export_to_csv_url(@table.name)}"
    response.status.should be_success
    
    path = "/tmp/temp_csv.zip"
    fd = File.open(path,'w+')
    fd.write(response.body)
    fd.close
    Zip::ZipFile.foreach(path) do |entry|
      entry.name.should == "antantaric_species_export.csv"
    end
    FileUtils.rm_rf(path)
  end

  scenario "Get table in SHP format" do
    response = get "#{api_table_export_to_shp_url(@table.name)}"
    response.status.should be_success
    
    path = "/tmp/temp_shp.zip"
    fd = File.open(path,'w+')
    fd.write(response.body)
    fd.close
    Zip::ZipFile.foreach(path) do |entry|
      %W{ antantaric_species_export.shp antantaric_species_export.dbf antantaric_species_export.prj }.should include(entry.name)
    end
    FileUtils.rm_rf(path)
  end
  
end