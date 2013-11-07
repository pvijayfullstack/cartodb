# encoding: utf-8
require_relative '../../spec_helper'
require_relative '../../../services/data-repository/backend/sequel'
require_relative '../../../app/models/visualization/member'
require_relative '../../../app/models/visualization/migrator'
require_relative '../../../services/data-repository/repository'

include CartoDB

describe Visualization::Member do
  before do
    memory = DataRepository.new
    Visualization.repository  = memory
    Overlay.repository        = memory
  end

  describe '#initialize' do
    it 'assigns an id by default' do
      member = Visualization::Member.new
      member.should be_an_instance_of Visualization::Member
      member.id.should_not be_nil
    end
  end #initialize

  describe '#store' do
    it 'persists attributes to the data repository' do
      attributes  = random_attributes
      member      = Visualization::Member.new(attributes)
      member.store

      member = Visualization::Member.new(id: member.id)
      member.name.should be_nil

      member.fetch
      member.name             .should == attributes.fetch(:name)
      member.active_layer_id  .should == attributes.fetch(:active_layer_id)
      member.privacy          .should == attributes.fetch(:privacy)
    end

    it 'persists tags as an array if the backend supports it' do
      db_config   = Rails.configuration.database_configuration[Rails.env]
      db          = Sequel.postgres(
                      host:     db_config.fetch('host'),
                      port:     db_config.fetch('port'),
                      username: db_config.fetch('username')
                    )
      relation    = "visualizations_#{Time.now.to_i}".to_sym
      repository  = DataRepository::Backend::Sequel.new(db, relation)
      Visualization::Migrator.new(db).migrate(relation)
      attributes  = random_attributes(tags: ['tag 1', 'tag 2'])
      member      = Visualization::Member.new(attributes, repository)
      member.store
      
      member      = Visualization::Member.new({ id: member.id }, repository)
      member.fetch
      member.tags.should include('tag 1')
      member.tags.should include('tag 2')

      Visualization::Migrator.new(db).drop(relation)
    end

    it 'persists tags as JSON if the backend does not support arrays' do
      attributes  = random_attributes(tags: ['tag 1', 'tag 2'])
      member      = Visualization::Member.new(attributes)
      member.store

      member = Visualization::Member.new(id: member.id)
      member.fetch
      member.tags.should include('tag 1')
      member.tags.should include('tag 2')
    end

    it 'invalidates vizjson cache in varnish if name changed' do
      member      = Visualization::Member.new(random_attributes)
      member.store

      member.expects(:invalidate_varnish_cache)
      member.name = 'changed'
      member.store
    end

    it 'invalidates vizjson cache in varnish if privacy changed' do
      member      = Visualization::Member.new(random_attributes)
      member.store

      member.expects(:invalidate_varnish_cache)
      member.privacy = 'private'
      member.store
    end

    it 'invalidates vizjson cache in varnish if description changed' do
      member      = Visualization::Member.new(random_attributes)
      member.store

      member.expects(:invalidate_varnish_cache)
      member.description = 'changed description'
      member.store
    end
  end #store

  describe '#fetch' do
    it 'fetches attributes from the data repository' do
      attributes  = random_attributes
      member      = Visualization::Member.new(attributes).store
      member      = Visualization::Member.new(id: member.id)
      member.name = 'changed'
      member.fetch
      member.name.should == attributes.fetch(:name)
    end
  end #fetch

  describe '#delete' do
    it 'deletes this member data from the data repository' do
      member = Visualization::Member.new(random_attributes).store
      member.fetch
      member.name.should_not be_nil

      member.delete
      member.name.should be_nil

      lambda { member.fetch }.should raise_error KeyError
    end

    it 'invalidates vizjson cache' do
      member      = Visualization::Member.new(random_attributes)
      member.store

      member.expects(:invalidate_varnish_cache)
      member.delete
    end
  end #delete

  describe '#unlink_from' do
    it 'invalidates varnish cache' do
      member = Visualization::Member.new(random_attributes).store
      member.expects(:invalidate_varnish_cache)
      member.expects(:remove_layers_from)
      member.unlink_from(Object.new)
    end
  end #unlink_from

  describe '#public?' do
    it 'returns true if privacy set to public' do
      visualization = Visualization::Member.new(privacy: 'public')
      visualization.public?.should == true

      visualization.privacy = 'private'
      visualization.public?.should == false

      visualization.privacy = 'public'
      visualization.public?.should == true
    end
  end #public?

  describe '#authorize?' do
    it 'returns true if user maps include map_id' do
      map_id  = rand(99)
      member  = Visualization::Member.new(name: 'foo', map_id: map_id)

      maps    = [OpenStruct.new(id: map_id)]
      user    = OpenStruct.new(maps: maps)
      member.authorize?(user).should == true

      maps    = [OpenStruct.new(id: 999)]
      user    = OpenStruct.new(maps: maps)
      member.authorize?(user).should == false
    end
  end #authorize?

  describe 'validations' do
    describe '#privacy' do
      it 'must be present' do
        visualization = Visualization::Member.new
        visualization.valid?.should == false
        visualization.errors.fetch(:privacy).should_not be_nil
      end

      it 'must be valid' do
        visualization = Visualization::Member.new(privacy: 'wadus')
        visualization.valid?.should == false
        visualization.errors.fetch(:privacy).should_not be_nil
      end
    end # privacy

    describe '#name' do
      it 'must be available for the user (uniqueness)' do
        pending
      end

      it 'downcases names for table_visualizations' do
        visualization = Visualization::Member.new(type: 'table')
        visualization.name = 'visualization_1'
        visualization.name.should == 'visualization_1'
        visualization.name = 'Visualization_1'
        visualization.name.should == 'visualization_1'

        visualization = Visualization::Member.new(type: 'derived')
        visualization.name = 'Visualization 1'
        visualization.name.should == 'Visualization 1'
      end
    end #name

    describe '#full_errors' do
      it 'returns full error messages' do
        visualization = Visualization::Member.new
        visualization.valid?.should == false

        visualization.full_errors.join("\n").should =~ /privacy/
        visualization.full_errors.join("\n").should =~ /type/
        visualization.full_errors.join("\n").should =~ /name/
      end
    end
  end # validations

  describe '#derived?' do
    it "returns true if type is derived" do
      visualization = Visualization::Member.new(type: 'derived')
      visualization.derived?.should be_true
      visualization.table?.should be_false

      visualization.type = 'bogus'
      visualization.derived?.should be_false
      visualization.table?.should be_false
    end
  end #derived?

  describe '#table?' do
    it "returns true if type is 'table'" do
      visualization = Visualization::Member.new(type: 'table')
      visualization.derived?.should be_false
      visualization.table?.should be_true

      visualization.type = 'bogus'
      visualization.derived?.should be_false
      visualization.table?.should be_false
    end
  end

  def random_attributes(attributes={})
    random = rand(999)
    {
      name:         attributes.fetch(:name, "name #{random}"),
      description:  attributes.fetch(:description, "description #{random}"),
      privacy:      attributes.fetch(:privacy, 'public'),
      tags:         attributes.fetch(:tags, ['tag 1']),
      type:         attributes.fetch(:type, 'table'),
      active_layer_id: random
    }
  end #random_attributes
end # Visualization

