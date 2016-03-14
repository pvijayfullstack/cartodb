# coding: UTF-8
require_relative '../../spec_helper_min'

describe Carto::Overlay do

  include Carto::Factories::Visualizations

  before(:all) do
    @user = FactoryGirl.create(:carto_user)
    @map, @table, @table_visualization, @visualization = create_full_visualization(@user)
  end

  after(:all) do
    destroy_full_visualization(@map, @table, @table_visualization, @visualization)
    # This avoids connection leaking.
    ::User[@user.id].destroy
  end

  describe '#create' do
    it 'creates a new overlay' do
      overlay = Carto::Overlay.new(visualization_id: @visualization.id, type: 'header', template: 'wadus', order: 0)
      overlay.save.should be_true

      overlay.id.should be
      overlay.visualization_id.should eq @visualization.id
      overlay.type.should eq 'header'
      overlay.template.should eq 'wadus'
      overlay.order.should eq 0
    end

    it 'validates unique overlays constraints' do
      overlay = Carto::Overlay.new(visualization_id: @visualization.id, type: 'search')
      overlay.save.should be_true

      overlay2 = Carto::Overlay.new(visualization_id: @visualization.id, type: 'search')
      overlay2.save.should be_false
    end

    it 'allows multiple overlays for non-unique types' do
      overlay = Carto::Overlay.new(visualization_id: @visualization.id, type: 'text')
      overlay.save.should be_true

      overlay2 = Carto::Overlay.new(visualization_id: @visualization.id, type: 'text')
      overlay2.save.should be_true
    end
  end

  describe '#update' do
    it 'updates overlays' do
      overlay = Carto::Overlay.new(visualization_id: @visualization.id, type: 'text', template: 'wadus', order: 0)
      overlay.save.should be_true

      overlay.template = 'image'
      overlay.type = 'logo'
      overlay.order = 5
      overlay.save.should be_true

      overlay.reload
      overlay.template.should eq 'image'
      overlay.type.should eq 'logo'
      overlay.order.should eq 5
    end

    it 'validates unique overlays constraints' do
      overlay = Carto::Overlay.new(visualization_id: @visualization.id, type: 'zoom')
      overlay.save.should be_true

      overlay2 = Carto::Overlay.new(visualization_id: @visualization.id, type: 'text')
      overlay2.save.should be_true

      overlay2.type = 'zoom'
      overlay2.save.should be_false
    end
  end

end
