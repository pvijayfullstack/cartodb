var cdb = require('cartodb.js');
var InfowindowContentView = require('./infowindow/infowindow-content-view');
var InfowindowContentHoverView = require('./infowindow/infowindow-content-view');
var createTextLabelsTabPane = require('../../../components/tab-pane/create-text-labels-tab-pane');
var TabPaneTemplate = require('../../tab-pane-submenu.tpl');

module.exports = cdb.core.View.extend({

  initialize: function (opts) {
    if (!opts.configModel) throw new Error('configModel is required');
    if (!opts.layerDefinitionModel) throw new Error('Layer definition is required');
    this._configModel = opts.configModel;
    this.layerDefinitionModel = opts.layerDefinitionModel;
    this._layerTableModel = this.layerDefinitionModel.layerTableModel;
    this._layerInfowindowModel = this.layerDefinitionModel.infowindowModel;
    this._layerTooltipModel = this.layerDefinitionModel.tooltipModel;

    if (!this._layerTableModel.get('fetched')) {
      this.listenToOnce(this._layerTableModel, 'change:fetched', this.render);
      this._layerTableModel.fetch();
    }
  },

  render: function () {
    this.clearSubViews();
    this.$el.empty();

    this._initViews();

    return this;
  },

  _initViews: function () {
    var self = this;

    var tabPaneTabs = [{
      label: _t('editor.layers.infowindow-menu-tab-pane-labels.click'),
      createContentView: function () {
        return new InfowindowContentView({
          layerDefinitionModel: self.layerDefinitionModel,
          layerTableModel: self._layerTableModel,
          layerInfowindowModel: self._layerInfowindowModel
        });
      }
    }, {
      label: _t('editor.layers.infowindow-menu-tab-pane-labels.hover'),
      createContentView: function () {
        return new InfowindowContentHoverView({
          layerDefinitionModel: self.layerDefinitionModel,
          layerTableModel: self._layerTableModel,
          layerInfowindowModel: self._layerTooltipModel
        });
      }
    }];

    var tabPaneOptions = {
      tabPaneOptions: {
        template: TabPaneTemplate,
        tabPaneItemOptions: {
          tagName: 'li',
          className: 'CDB-NavSubmenu-item'
        }
      },
      tabPaneItemLabelOptions: {
        tagName: 'button',
        className: 'CDB-NavSubmenu-link u-upperCase'
      }
    };

    this._layerTabPaneView = createTextLabelsTabPane(tabPaneTabs, tabPaneOptions);
    this.$el.append(this._layerTabPaneView.render().$el);
    this.addView(this._layerTabPaneView);
  }
});
