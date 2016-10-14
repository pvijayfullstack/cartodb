var Backbone = require('backbone');
var ConfigModel = require('../../../javascripts/cartodb3/data/config-model');
var LegendManager = require('../../../javascripts/cartodb3/deep-insights-integration/legend-manager');
var LegendFactory = require('../../../javascripts/cartodb3/editor/layers/layer-content-views/legend/legend-factory');
var LayerDefinitionModel = require('../../../javascripts/cartodb3/data/layer-definition-model');
var StyleDefinitionModel = require('../../../javascripts/cartodb3/editor/style/style-definition-model');
var LegendDefinitionsCollection = require('../../../javascripts/cartodb3/data/legends/legend-definitions-collection');

describe('deep-insights-integrations/legend-manager', function () {
  beforeEach(function () {
    this.configModel = new ConfigModel({
      base_url: '/u/pepe'
    });

    this.styleModel = new StyleDefinitionModel({
      type: 'simple'
    }, {
      parse: true
    });

    this.layerDefinitionModel = new LayerDefinitionModel({
      id: 'l-1',
      fetched: true,
      options: {
        type: 'CartoDB',
        table_name: 'foo',
        cartocartocss: 'asd',
        source: 'a0'
      }
    }, {
      parse: true,
      configModel: this.configModel
    });

    this.layerDefinitionModel.styleModel = this.styleModel;

    this.layerDefinitionsCollection = new Backbone.Collection();
    this.layerDefinitionsCollection.add(this.layerDefinitionModel);

    this.legendDefinitionsCollection = new LegendDefinitionsCollection(null, {
      configModel: this.configModel,
      layerDefinitionsCollection: this.layerDefinitionsCollection,
      vizId: 'v-123'
    });

    LegendFactory.init(this.legendDefinitionsCollection);

    spyOn(LegendFactory, 'createLegend');
    spyOn(LegendFactory, 'hasMigratedLegend').and.returnValue(false);

    LegendManager.track(this.layerDefinitionModel);
  });

  describe('points', function () {
    it('styles fixed', function () {
      this.styleModel.set('fill', {
        color: {
          fixed: '#fabada'
        },
        size: {
          fixed: 7
        }
      });

      this.layerDefinitionModel.set({
        cartocss: 'wadus'
      });

      expect(LegendFactory.createLegend).not.toHaveBeenCalled();
    });

    it('styles size', function () {
      this.styleModel.set('fill', {
        color: {
          fixed: '#045275'
        },
        size: {
          attribute: 'number',
          range: [1.05, 1.95]
        }
      });

      this.layerDefinitionModel.set({
        cartocss: 'wadus'
      });
      expect(LegendFactory.createLegend).toHaveBeenCalledWith(this.layerDefinitionModel, 'bubble', {title: 'number'});
    });

    it('styles color', function () {
      this.styleModel.set('fill', {
        color: {
          attribute: 'number',
          attribute_type: 'number',
          bins: '3',
          quantification: 'quantiles',
          range: ['#ffc6c4', '#cc607d', '#672044']
        },
        size: {
          attribute: 'number',
          quantification: 'quantiles',
          range: [1.05, 1.95]
        }
      });

      this.layerDefinitionModel.set({
        cartocss: 'wadus'
      });

      expect(LegendFactory.createLegend).toHaveBeenCalledTimes(2);
      expect(LegendFactory.createLegend).toHaveBeenCalledWith(this.layerDefinitionModel, 'bubble', {title: 'number'});
      expect(LegendFactory.createLegend).toHaveBeenCalledWith(this.layerDefinitionModel, 'choropleth', {title: 'number'});
    });
  });

  describe('lines', function () {
    it('styles fixed', function () {
      this.styleModel.set('fill', {
        color: {
          fixed: '#fabada'
        },
        size: {
          fixed: 7
        }
      });

      this.layerDefinitionModel.set({
        cartocss: 'wadus'
      });

      expect(LegendFactory.createLegend).not.toHaveBeenCalled();
    });

    it('styles size', function () {
      this.styleModel.set('stroke', {
        color: {
          fixed: '#045275'
        },
        size: {
          attribute: 'number',
          range: [1.05, 1.95]
        }
      });

      this.layerDefinitionModel.set({
        cartocss: 'wadus'
      });
      expect(LegendFactory.createLegend).toHaveBeenCalledWith(this.layerDefinitionModel, 'bubble', {title: 'number'});
    });

    it('styles color', function () {
      this.styleModel.set('stroke', {
        color: {
          attribute: 'number',
          attribute_type: 'number',
          bins: '3',
          quantification: 'quantiles',
          range: ['#ffc6c4', '#cc607d', '#672044']
        },
        size: {
          attribute: 'number',
          quantification: 'quantiles',
          range: [1.05, 1.95]
        }
      });

      this.layerDefinitionModel.set({
        cartocss: 'wadus'
      });

      expect(LegendFactory.createLegend).toHaveBeenCalledTimes(2);
      expect(LegendFactory.createLegend).toHaveBeenCalledWith(this.layerDefinitionModel, 'bubble', {title: 'number'});
      expect(LegendFactory.createLegend).toHaveBeenCalledWith(this.layerDefinitionModel, 'choropleth', {title: 'number'});
    });
  });
});
