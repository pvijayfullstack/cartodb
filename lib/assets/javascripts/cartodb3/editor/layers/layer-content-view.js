var cdb = require('cartodb.js');
var _ = require('underscore');
var createTextLabelsTabPane = require('../../components/tab-pane/create-text-labels-tab-pane');
var TabPaneTemplate = require('./layer-tab-pane.tpl');
var Header = require('./layer-header-view.js');
var AnalysesView = require('./layer-content-views/analyses-view');
var StyleView = require('../style/style-view');

module.exports = cdb.core.View.extend({
  events: {
    'click .js-back': '_onClickBack'
  },

  initialize: function (opts) {
    if (!opts.layerDefinitionsCollection) throw new Error('layerDefinitionsCollection is required');
    if (!opts.layerDefinitionModel) throw new Error('layerDefinitionModel is required');
    if (!opts.stackLayoutModel) throw new Error('StackLayoutModel is required');
    if (!opts.analysisDefinitionsCollection) throw new Error('analysisDefinitionsCollection is required');
    if (!opts.analysisDefinitionNodesCollection) throw new Error('analysisDefinitionNodesCollection is required');
    if (!opts.modals) throw new Error('modals is required');
    if (!opts.analysis) throw new Error('analysis is required');

    this.layerDefinitionModel = opts.layerDefinitionModel;
    this.analysisDefinitionNodesCollection = opts.analysisDefinitionNodesCollection;
    this.analysisDefinitionsCollection = opts.analysisDefinitionsCollection;
    this.layerDefinitionsCollection = opts.layerDefinitionsCollection;
    this.stackLayoutModel = opts.stackLayoutModel;
    this.modals = opts.modals;
    this.analysis = opts.analysis;
  },

  render: function () {
    var self = this;
    var tabPaneTabs = [{
      label: _t('editor.layers.menu-tab-pane-labels.data'),
      selected: !this.options.selectedNodeId,
      createContentView: function () {
        return new cdb.core.View();
      }
    }, {
      label: _t('editor.layers.menu-tab-pane-labels.analyses'),
      selected: this.options.selectedNodeId,
      createContentView: function () {
        return new AnalysesView({
          layerDefinitionModel: self.layerDefinitionModel,
          analysisDefinitionsCollection: self.analysisDefinitionsCollection,
          modals: self.modals,
          analysis: self.analysis,
          selectedNodeId: self.options.selectedNodeId
        });
      }
    }, {
      label: _t('editor.layers.menu-tab-pane-labels.style'),
      createContentView: function () {
        var lastLayerNodeModel = _.first(
          self.analysisDefinitionNodesCollection.where({
            id: self.layerDefinitionModel.get('source')
          })
        );
        var querySchemaModel = lastLayerNodeModel.querySchemaModel;
        var queryGeometryModel = new cdb.core.Model({
          geometry_type: 'point'
        });

        return new StyleView({
          analysisDefinitionsCollection: self.analysisDefinitionsCollection,
          querySchemaModel: querySchemaModel,
          queryGeometryModel: queryGeometryModel,
          layerDefinitionsCollection: self.layerDefinitionsCollection,
          layerDefinitionModel: self.layerDefinitionModel,
          modals: self.modals
        });
      }
    }, {
      label: _t('editor.layers.menu-tab-pane-labels.popup'),
      createContentView: function () {
        return new cdb.core.View();
      }
    }, {
      label: _t('editor.layers.menu-tab-pane-labels.legends'),
      createContentView: function () {
        return new cdb.core.View();
      }
    }];

    var header = new Header({
      layerDefinitionModel: this.layerDefinitionModel
    });
    this.addView(header);
    this.$el.append(header.render().$el);

    var tabPaneOptions = {
      tabPaneOptions: {
        tagName: 'nav',
        className: 'CDB-NavMenu',
        template: TabPaneTemplate,
        tabPaneItemOptions: {
          tagName: 'li',
          className: 'CDB-NavMenu-item'
        }
      },
      tabPaneItemLabelOptions: {
        tagName: 'button',
        className: 'CDB-NavMenu-link u-upperCase'
      }
    };

    this._layerTabPaneView = createTextLabelsTabPane(tabPaneTabs, tabPaneOptions);
    this.$el.append(this._layerTabPaneView.render().$el);
    this.addView(this._layerTabPaneView);
    return this;
  },

  _onClickBack: function () {
    this.stackLayoutModel.prevStep('layers');
  }
});
