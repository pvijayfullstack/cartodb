# encoding: utf-8
require 'minitest/autorun'
require_relative '../../../services/data-repository/backend/sequel'
require_relative '../../../app/models/visualization/member'
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
      member.must_be_instance_of Visualization::Member
      member.id.wont_be_nil
    end
  end #initialize

  describe '#store' do
    it 'persists attributes to the data repository' do
      member = Visualization::Member.new(name: 'foo')
      member.store

      member = Visualization::Member.new(id: member.id)
      member.name.must_be_nil

      member.fetch
      member.name.must_equal 'foo'
    end

    it 'persists tags as an array if the backend supports it' do
      db          = Sequel.postgres(host: 'localhost', port: 5432)
      relation    = :"visualizations_#{Time.now.to_i}"
      create_visualizations_table_in(db, relation)

      repository  = DataRepository::Backend::Sequel.new(db, relation)
      attributes  = { name: 'foo', tags: ['tag 1', 'tag 2'] }
      member      = Visualization::Member.new(attributes, repository)
      member.store
      
      member      = Visualization::Member.new({ id: member.id }, repository)
      member.fetch
      member.tags.must_include('tag 1')
      member.tags.must_include('tag 2')

      drop_table_from(db, relation)
    end

    it 'persists tags as JSON if the backend does not support arrays' do
      member = Visualization::Member.new(name: 'foo', tags: ['tag 1', 'tag 2'])
      member.store

      member = Visualization::Member.new(id: member.id)
      member.fetch
      member.tags.must_include('tag 1')
      member.tags.must_include('tag 2')
    end
  end #store

  describe '#fetch' do
    it 'fetches attributes from the data repository' do
      member = Visualization::Member.new(name: 'foo')
      member.store

      member = Visualization::Member.new(id: member.id)
      member.name = 'changed'
      member.fetch
      member.name.must_equal 'foo'
    end
  end #fetch

  describe '#delete' do
    it 'deletes this member data from the data repository' do
      member = Visualization::Member.new(name: 'foo')
      member.store

      member.fetch
      member.name.wont_be_nil

      member.delete
      member.name.must_be_nil

      lambda { member.fetch }.must_raise KeyError
    end
  end #delete

  def create_visualizations_table_in(db, relation)
    db.create_table relation do
      String    :id, primary_key: true
      String    :name
      String    :description
      String    :map_id
      String    :type
    end

    db.run(%Q{
      ALTER TABLE "#{relation}"
      ADD COLUMN tags text[]
    })
  end #create_visualizations_table_in

  def drop_table_from(db, relation)
    db.drop_table relation.to_sym
  end #drop_table_from
end # Visualization

