var _ = require('underscore');
var LayerDefinitionsCollection = require('../../../../../../../javascripts/cartodb3/data/layer-definitions-collection');
var LayerDefinitionModel = require('../../../../../../../javascripts/cartodb3/data/layer-definition-model');
var InfowindowsView = require('../../../../../../../javascripts/cartodb3/editor/layers/layer-content-views/infowindow/infowindows-view');
var ConfigModel = require('../../../../../../../javascripts/cartodb3/data/config-model');
var UserModel = require('../../../../../../../javascripts/cartodb3/data/user-model');
var QuerySchemaModel = require('../../../../../../../javascripts/cartodb3/data/query-schema-model');
var QueryGeometryModel = require('../../../../../../../javascripts/cartodb3/data/query-geometry-model');
var InfowindowView = require('../../../../../../../javascripts/cartodb3/editor/layers/layer-content-views/infowindow/infowindow-click-view');
var TooltipView = require('../../../../../../../javascripts/cartodb3/editor/layers/layer-content-views/infowindow/infowindow-hover-view');
var InfowindowDefinitionModel = require('../../../../../../../javascripts/cartodb3/data/infowindow-definition-model');
var EditorModel = require('../../../../../../../javascripts/cartodb3/data/editor-model');
var UserActions = require('../../../../../../../javascripts/cartodb3/data/user-actions');
var AnalysisDefinitionNodesCollection = require('../../../../../../../javascripts/cartodb3/data/analysis-definition-nodes-collection');
var AnalysisDefinitionsCollection = require('../../../../../../../javascripts/cartodb3/data/analysis-definitions-collection');
var QueryRowsCollection = require('../../../../../../../javascripts/cartodb3/data/query-rows-collection');

describe('editor/layers/layer-content-view/infowindow/infowindows-view', function () {
  beforeEach(function () {
    this.configModel = new ConfigModel({
      base_url: '/u/pepe'
    });

    this.userModel = new UserModel({}, {
      configModel: this.configModel
    });
    spyOn(this.userModel, 'featureEnabled').and.returnValue(true);

    this.analysisDefinitionNodesCollection = new AnalysisDefinitionNodesCollection(null, {
      configModel: this.configModel,
      userModel: this.userModel
    });

    this.a0 = this.analysisDefinitionNodesCollection.add({
      id: 'a0',
      type: 'source',
      table_name: 'foo'
    });
    spyOn(this.a0, 'isCustomQueryApplied').and.returnValue(false);

    this.layerDefinitionsCollection = new LayerDefinitionsCollection(null, {
      configModel: this.configModel,
      userModel: this.userModel,
      analysisDefinitionNodesCollection: this.analysisDefinitionNodesCollection,
      mapId: 'm123',
      stateDefinitionModel: {}
    });

    this.analysisDefinitionsCollection = new AnalysisDefinitionsCollection(null, {
      configModel: this.configModel,
      vizId: 'viz-123',
      analysisDefinitionNodesCollection: this.analysisDefinitionNodesCollection,
      layerDefinitionsCollection: this.layerDefinitionsCollection
    });

    this.querySchemaModel = new QuerySchemaModel({
      query: 'SELECT * FROM foobar',
      status: 'fetched'
    }, {
      configModel: this.configModel
    });
    this.querySchemaModel.columnsCollection.reset([
      {
        type: 'number',
        name: 'cartodb_id'
      }, {
        type: 'number',
        name: 'a_number'
      }
    ]);
    spyOn(this.querySchemaModel, 'fetch');

    this.queryGeometryModel = new QueryGeometryModel({
      query: 'SELECT * FROM foobar',
      status: 'fetched',
      simple_geom: 'point'
    }, {
      configModel: this.configModel
    });
    spyOn(this.queryGeometryModel, 'fetch');

    this.queryRowsCollection = new QueryRowsCollection([], {
      configModel: this.configModel,
      querySchemaModel: this.querySchemaModel
    });

    spyOn(this.queryRowsCollection, 'fetch');

    this.layerDefinitionModel = new LayerDefinitionModel({
      id: 'l-1',
      fetched: true,
      options: {
        type: 'CartoDB',
        table_name: 'foo',
        cartocss: 'asd',
        source: 'a0'
      },
      infowindow: {
        template_name: '',
        template: ''
      },
      tooltip: {
        template_name: '',
        template: ''
      }
    }, {
      parse: true,
      configModel: this.configModel
    });
    spyOn(this.layerDefinitionModel, 'save');
    spyOn(this.layerDefinitionModel, 'getAnalysisDefinitionNodeModel').and.returnValue(this.a0);

    spyOn(InfowindowsView.prototype, '_fetchAllQueryObjectsIfNecessary').and.callThrough();
  });

  describe('when layer has infowindowModel', function () {
    beforeEach(function () {
      this.view = new InfowindowsView({
        configModel: this.configModel,
        editorModel: new EditorModel(),
        userActions: new UserActions({
          userModel: this.userModel,
          analysisDefinitionsCollection: this.analysisDefinitionsCollection,
          analysisDefinitionNodesCollection: this.analysisDefinitionNodesCollection,
          layerDefinitionsCollection: this.layerDefinitionsCollection,
          widgetDefinitionsCollection: {}
        }),
        layerDefinitionModel: this.layerDefinitionModel,
        querySchemaModel: this.querySchemaModel,
        queryGeometryModel: this.queryGeometryModel,
        queryRowsCollection: this.queryRowsCollection
      });

      this.view.render();
    });

    it('should fetch (if necessary) all query objects', function () {
      expect(InfowindowsView.prototype._fetchAllQueryObjectsIfNecessary).toHaveBeenCalled();
    });

    it('should render loading view if query-geometry-model is fetching', function () {
      spyOn(this.queryGeometryModel, 'isFetching').and.returnValue(true);

      this.view.render();

      expect(this.view.$el.html()).toContain('FormPlaceholder-paragraph');
    });

    it('should render two tabs', function () {
      expect(this.view._layerTabPaneView).toBeDefined();
      expect(_.size(this.view._layerTabPaneView._subviews)).toBe(3); // 2 tabs, 1 pane
      expect(this.view.$('.CDB-NavSubmenu .CDB-NavSubmenu-item').length).toBe(2);
      expect(this.view.$('.CDB-NavSubmenu-item:eq(0)').text()).toContain('editor.layers.infowindow-menu-tab-pane-labels.click');
      expect(this.view.$('.CDB-NavSubmenu-item:eq(0) .CDB-NavSubmenu-status').text()).toBe('editor.layers.infowindow.style.none');
      expect(this.view.$('.CDB-NavSubmenu-item:eq(1)').text()).toContain('editor.layers.infowindow-menu-tab-pane-labels.hover');
      expect(this.view.$('.CDB-NavSubmenu-item:eq(1) .CDB-NavSubmenu-status').text()).toContain('editor.layers.tooltip.style.none');
    });

    it('should change tab if infowindow (and tooltip) changes', function () {
      expect(this.view.$('.CDB-NavSubmenu-item:eq(0) .CDB-NavSubmenu-status').text()).toBe('editor.layers.infowindow.style.none');
      expect(this.view.$('.CDB-NavSubmenu-item:eq(1) .CDB-NavSubmenu-status').text()).toBe('editor.layers.tooltip.style.none');
      this.view._layerInfowindowModel.set('template_name', 'infowindow_dark');

      this.view.render();

      expect(this.view.$('.CDB-NavSubmenu-item:eq(0) .CDB-NavSubmenu-status').text()).toBe('editor.layers.infowindow.style.infowindow_dark');
      expect(this.view.$('.CDB-NavSubmenu-item:eq(1) .CDB-NavSubmenu-status').text()).toBe('editor.layers.tooltip.style.none');

      // change tab and change template_name, '.js-menu .CDB-NavSubmenu-item.is-selected .js-NavSubmenu-status' is needed
      this.view._layerTabPaneView.collection.at(1).set('selected', true);
      this.view._layerTooltipModel.set('template_name', 'tooltip_dark');

      this.view.render();

      expect(this.view.$('.CDB-NavSubmenu-item:eq(0) .CDB-NavSubmenu-status').text()).toBe('editor.layers.infowindow.style.infowindow_dark');
      expect(this.view.$('.CDB-NavSubmenu-item:eq(1) .CDB-NavSubmenu-status').text()).toBe('editor.layers.tooltip.style.tooltip_dark');
    });

    it('should fetch all query objects when query-geometry-model query has changed', function () {
      InfowindowsView.prototype._fetchAllQueryObjectsIfNecessary.calls.reset();
      this.queryGeometryModel.set('query', 'dummy query');
      expect(this.queryGeometryModel.get('status')).toBe('unfetched');
      expect(InfowindowsView.prototype._fetchAllQueryObjectsIfNecessary.calls.count()).toBe(1);
    });

    describe('infowindows tabs', function () {
      var model;

      beforeEach(function () {
        model = new InfowindowDefinitionModel({}, {
          configModel: this.configModel
        });
      });

      it('infowindow should render properly', function () {
        var view = new InfowindowView({
          layerDefinitionModel: this.layerDefinitionModel,
          querySchemaModel: this.querySchemaModel,
          userActions: {},
          model: model,
          editorModel: new EditorModel()
        });

        view.render();

        expect(_.size(view._subviews)).toBe(1); // fields / codemirror view
      });

      it('tooltip should render properly', function () {
        var view = new TooltipView({
          layerDefinitionModel: this.layerDefinitionModel,
          querySchemaModel: this.querySchemaModel,
          userActions: {},
          model: model,
          editorModel: new EditorModel()
        });

        view.render();

        expect(_.size(view._subviews)).toBe(1); // fields / codemirror view
      });
    });

    it('should render placeholder if style model type is aggregated', function () {
      expect(_.size(this.view._subviews)).toBe(2);
      expect(this.view.$('.CDB-Size-huge').length).toBe(0);

      spyOn(this.layerDefinitionModel.styleModel, 'isAggregatedType').and.returnValue(true);

      this.view.render();

      expect(_.size(this.view._subviews)).toBe(1);
      expect(this.view.$('.CDB-Size-huge').length).toBe(1);
      expect(this.view.$('.CDB-Size-huge').text()).toBe('editor.layers.infowindow.placeholder-interactivity-text');
    });

    it('should render placeholder if style model has animated enabled', function () {
      expect(_.size(this.view._subviews)).toBe(2);
      expect(this.view.$('.CDB-Size-huge').length).toBe(0);

      spyOn(this.layerDefinitionModel.styleModel, 'isAnimation').and.returnValue(true);

      this.view.render();

      expect(_.size(this.view._subviews)).toBe(1);
      expect(this.view.$('.CDB-Size-huge').length).toBe(1);
      expect(this.view.$('.CDB-Size-huge').text()).toBe('editor.layers.infowindow.placeholder-interactivity-text');
    });

    it('should render placeholder when querySchemaModel is unfetched', function () {
      expect(_.size(this.view._subviews)).toBe(2);
      expect(this.view.$('.CDB-Size-huge').length).toBe(0);

      this.querySchemaModel.set('status', 'unfetched');

      this.view.render();

      expect(_.size(this.view._subviews)).toBe(1);
      expect(this.view.$('.CDB-Size-huge').length).toBe(1);
      expect(this.view.$('.CDB-Size-huge').text()).toBe('editor.layers.infowindow.placeholder-columns-text');
    });

    it('should render placeholder when has no columns', function () {
      expect(_.size(this.view._subviews)).toBe(2);
      expect(this.view.$('.CDB-Size-huge').length).toBe(0);

      this.querySchemaModel.columnsCollection.reset([
        {
          type: 'number',
          name: 'cartodb_id'
        }
      ]);

      this.view.render();

      expect(_.size(this.view._subviews)).toBe(1);
      expect(this.view.$('.CDB-Size-huge').length).toBe(1);
      expect(this.view.$('.CDB-Size-huge').text()).toBe('editor.layers.infowindow.placeholder-columns-text');
    });

    it('should not have any leaks', function () {
      expect(this.view).toHaveNoLeaks();
    });
  });

  describe('when layer has no geometry', function () {
    beforeEach(function () {
      this.view = new InfowindowsView({
        configModel: this.configModel,
        editorModel: new EditorModel(),
        userActions: new UserActions({
          userModel: this.userModel,
          analysisDefinitionsCollection: this.analysisDefinitionsCollection,
          analysisDefinitionNodesCollection: this.analysisDefinitionNodesCollection,
          layerDefinitionsCollection: this.layerDefinitionsCollection,
          widgetDefinitionsCollection: {}
        }),
        layerDefinitionModel: this.layerDefinitionModel,
        querySchemaModel: this.querySchemaModel,
        queryGeometryModel: this.queryGeometryModel,
        queryRowsCollection: this.queryRowsCollection
      });

      this.view.render();
    });

    it('should render placeholder', function () {
      expect(_.size(this.view._subviews)).toBe(2);
      expect(this.view.$('.CDB-Size-huge').length).toBe(0);

      this.queryGeometryModel.set('simple_geom', '');

      this.view.render();

      expect(_.size(this.view._subviews)).toBe(1);
      expect(this.view.$('.CDB-Size-huge').length).toBe(1);
      expect(this.view.$('.CDB-Size-huge').text()).toBe('editor.layers.infowindow.placeholder-geometry');
    });

    it('should not have any leaks', function () {
      expect(this.view).toHaveNoLeaks();
    });
  });

  describe('when layer is non georeferenced', function () {
    beforeEach(function () {
      spyOn(this.layerDefinitionModel, 'canBeGeoreferenced').and.returnValue(true);

      this.view = new InfowindowsView({
        configModel: this.configModel,
        editorModel: new EditorModel(),
        userActions: new UserActions({
          userModel: this.userModel,
          analysisDefinitionsCollection: this.analysisDefinitionsCollection,
          analysisDefinitionNodesCollection: this.analysisDefinitionNodesCollection,
          layerDefinitionsCollection: this.layerDefinitionsCollection,
          widgetDefinitionsCollection: {}
        }),
        layerDefinitionModel: this.layerDefinitionModel,
        querySchemaModel: this.querySchemaModel,
        queryGeometryModel: this.queryGeometryModel,
        queryRowsCollection: this.queryRowsCollection
      });

      this.view.render();
    });

    it('should render placeholder', function () {
      expect(_.size(this.view._subviews)).toBe(2);
      expect(this.view.$('.CDB-Size-huge').length).toBe(0);

      this.queryGeometryModel.set('simple_geom', '');

      this.view.render();

      expect(_.size(this.view._subviews)).toBe(2);
      expect(this.view.$('.CDB-Size-huge').length).toBe(1);
      expect(this.view.$('.CDB-Size-huge').text()).toContain('editor.layers.infowindow.placeholder-geometry');
      expect(this.view.$('.CDB-Size-huge').text()).toContain('editor.layers.georeference.manually-add');
      expect(this.view.$('.CDB-Button-Text').text()).toBe('editor.layers.georeference.georeference-button');
    });

    it('should not have any leaks', function () {
      expect(this.view).toHaveNoLeaks();
    });
  });

  describe('when layer doesn\'t have infowindowModel (basemap, torque, ...)', function () {
    beforeEach(function () {
      var layerDefinitionModel = new LayerDefinitionModel({
        id: 'l-1',
        fetched: true,
        options: {
          type: 'CartoDB',
          table_name: 'foo',
          cartocss: 'asd',
          source: 'a0'
        }
      }, {
        parse: true,
        configModel: this.configModel
      });
      spyOn(layerDefinitionModel, 'save');
      spyOn(layerDefinitionModel, 'getAnalysisDefinitionNodeModel').and.returnValue(this.a0);

      this.view = new InfowindowsView({
        configModel: this.configModel,
        editorModel: new EditorModel(),
        userActions: {},
        layerDefinitionModel: layerDefinitionModel,
        querySchemaModel: this.querySchemaModel,
        queryGeometryModel: this.queryGeometryModel,
        queryRowsCollection: this.queryRowsCollection
      });

      this.view.render();
    });

    it('should render placeholder', function () {
      expect(this.view._layerTabPaneView).not.toBeDefined();
      expect(this.view.$('.CDB-Size-huge').length).toBe(1);
      expect(this.view.$('.CDB-Size-huge').text()).toBe('editor.layers.infowindow.placeholder-interactivity-text');
    });

    it('should not have any leaks', function () {
      expect(this.view).toHaveNoLeaks();
    });
  });
});
