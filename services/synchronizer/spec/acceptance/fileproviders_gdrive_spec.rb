# encoding: utf-8

require_relative '../../lib/synchronizer/file-providers/gdrive_provider'
require 'yaml'

include CartoDB::Synchronizer::FileProviders

describe GDriveProvider do

  def get_config
    @config ||= YAML.load_file("#{File.dirname(__FILE__)}/../../../../config/app_config.yml")['defaults']['oauth']['gdrive']
  end #get_config

  describe '#manual_test' do
    it 'with user interaction, tests the full oauth flow and lists files of an account' do
      config = get_config
      gdrive_provider = GDriveProvider.get_new(config)

      if config.include?(:refresh_token)
        gdrive_provider.token = config[:refresh_token]
      else
        pending('If config unset, this test requires manual running. Check its source code to see what to do')
        puts gdrive_provider.get_auth_url
        input = ''
        debugger
        gdrive_provider.validate_auth_code(input)
        puts gdrive_provider.token
      end
      data = gdrive_provider.get_files_list
      puts data
    end
  end

end

