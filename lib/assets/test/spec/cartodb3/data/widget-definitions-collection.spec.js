var Backbone = require('backbone');
var ConfigModel = require('../../../../javascripts/cartodb3/data/config-model');
var WidgetDefinitionsCollection = require('../../../../javascripts/cartodb3/data/widget-definitions-collection');

describe('data/widget-definitions-collection', function () {
  beforeEach(function () {
    var configModel = new ConfigModel({
      base_url: '/u/pepe'
    });

    this.layerDefinitionsCollection = new Backbone.Collection([{
      id: 'l-1'
    }]);

    this.analysisDefinitionNodesCollection = new Backbone.Collection();

    this.collection = new WidgetDefinitionsCollection(null, {
      configModel: configModel,
      analysisDefinitionNodesCollection: this.analysisDefinitionNodesCollection,
      layerDefinitionsCollection: this.layerDefinitionsCollection,
      mapId: 'm-123'
    });
  });

  describe('when a model is created', function () {
    beforeEach(function () {
      spyOn(this.layerDefinitionsCollection.get('l-1'), 'save');
      var histogram = {
        type: 'histogram',
        title: 'histogram',
        layer_id: 'l-1',
        source: {
          id: 'a0'
        },
        options: {
          column: 'col'
        }
      };
      this.collection.create(histogram);
    });

    it('should set a new order when a new widget is created', function () {
      var widget = this.collection.at(0);
      expect(widget.get('order')).toBe(0);
      widget.set('order', 10);
      var category = {
        type: 'category',
        title: 'category',
        layer_id: 'l-1',
        source: {
          id: 'a0'
        },
        options: {
          column: 'col'
        }
      };
      this.collection.create(category);
      var widget2 = this.collection.at(1);
      expect(widget2.get('order')).toBe(11);
    });

    it('should save layer to persist source when saved', function () {
      var m = this.collection.first();
      m.trigger('sync', m);
      expect(this.layerDefinitionsCollection.get('l-1').save).toHaveBeenCalled();
    });

    describe('when a analysis node is removed', function () {
      beforeEach(function () {
        this.analysisDefinitionNodesCollection.add({
          id: 'a0',
          type: 'source',
          query: 'SELECT * FROM foo'
        });
        this.analysisDefinitionNodesCollection.remove(this.analysisDefinitionNodesCollection.get('a0'));
      });

      it('should destroy all associated widgets', function () {
        expect(this.collection.isEmpty()).toBe(true);
      });
    });

    describe('when a layer is removed', function () {
      beforeEach(function () {
        this.layerDefinitionsCollection.remove(this.layerDefinitionsCollection.first());
      });

      it('should destroy all associated widgets', function () {
        expect(this.collection.isEmpty()).toBe(true);
      });
    });
  });
});
