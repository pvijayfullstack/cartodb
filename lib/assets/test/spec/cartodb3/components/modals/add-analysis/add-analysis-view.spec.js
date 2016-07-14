var Backbone = require('backbone');
var ConfigModel = require('../../../../../../javascripts/cartodb3/data/config-model');
var createGeometry = require('../../../../../../javascripts/cartodb3/value-objects/geometry');
var AnalysisDefinitionNodessCollection = require('../../../../../../javascripts/cartodb3/data/analysis-definition-nodes-collection');
var LayerDefinitionsCollection = require('../../../../../../javascripts/cartodb3/data/layer-definitions-collection');
var AddAnalysisView = require('../../../../../../javascripts/cartodb3/components/modals/add-analysis/add-analysis-view');

describe('components/modals/add-analysis/add-analysis-view', function () {
  beforeEach(function () {
    this.modalModel = new Backbone.Model();
    spyOn(this.modalModel, 'destroy');

    var configModel = new ConfigModel({
      base_url: '/u/pepe'
    });

    this.analysisDefinitionNodesCollection = new AnalysisDefinitionNodessCollection(null, {
      configModel: configModel
    });
    this.a0 = this.analysisDefinitionNodesCollection.add({
      id: 'a0',
      type: 'source',
      params: {
        query: 'SELECT * from alice'
      },
      options: {
        table_name: 'alice'
      }
    });
    this.layerDefinitionsCollection = new LayerDefinitionsCollection(null, {
      configModel: configModel,
      analysisDefinitionNodesCollection: this.analysisDefinitionNodesCollection,
      mapId: '123'
    });
    this.layerA = this.layerDefinitionsCollection.add({
      id: 'layerA',
      kind: 'carto',
      options: {
        source: 'a0',
        table_name: 'alice'
      }
    });

    this.querySchemaModel = this.a0.querySchemaModel;
    spyOn(this.querySchemaModel, 'sync');
    spyOn(this.querySchemaModel, 'fetch').and.callThrough();

    this.view = new AddAnalysisView({
      modalModel: this.modalModel,
      layerDefinitionModel: this.layerA
    });
    this.view.render();
  });

  it('should have no leaks', function () {
    expect(this.view).toHaveNoLeaks();
  });

  it('should render the loading view', function () {
    expect(this.view.$('.js-body').html()).toContain('loading');
  });

  describe('when geometry output type is fetched', function () {
    beforeEach(function () {
      spyOn(this.querySchemaModel, 'getGeometry').and.returnValue(createGeometry.ex('polygon'));
      this.querySchemaModel.sync.calls.argsFor(0)[2].success({
        fields: {},
        rows: []
      });
    });

    it('should render the content view', function () {
      expect(this.view.$('.js-body').html()).not.toContain('loading');
      expect(this.view.$('.js-body').html()).not.toContain('error');
    });

    describe('when click add when there is no selection', function () {
      it('should do nothing', function () {
        this.view.$('.js-add').click();
        expect(this.modalModel.destroy).not.toHaveBeenCalled();
      });
    });

    describe('when an option is selected', function () {
      beforeEach(function () {
        expect(this.view.$('.js-add').hasClass('is-disabled')).toBe(true);
        var $el = this.view.$('[title*=intersection]').first();
        expect($el.length).toEqual(1, 'should only click one item (the custom intersection one)');

        $el.click();
      });

      it('should enable add-button', function () {
        expect(this.view.$('.js-add').hasClass('is-disabled')).toBe(false);
      });

      describe('when click add', function () {
        beforeEach(function () {
          this.view.$('.js-add').click();
        });

        it('should destroy the modal and pass the created node model', function () {
          expect(this.modalModel.destroy).toHaveBeenCalled();
          expect(this.modalModel.destroy.calls.argsFor(0)).toEqual([
            jasmine.objectContaining({
              id: 'a1',
              source: 'a0',
              type: jasmine.any(String)
            })
          ]);
        });
      });
    });
  });
});
