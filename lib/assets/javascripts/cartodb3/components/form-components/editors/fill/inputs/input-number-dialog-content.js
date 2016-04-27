var cdb = require('cartodb.js');
var tabPaneTemplate = require('./../fill-tab-pane.tpl');
var createTextLabelsTabPane = require('../../../../../components/tab-pane/create-text-labels-tab-pane');

module.exports = cdb.core.View.extend({
  initialize: function (opts) {
  },

  render: function () {
    var tabPaneTabs = [{
      name: 'fixed',
      label: 'Fixed',
      selected: true,
      createContentView: function () {
        return new cdb.core.View();
      }
    }, {
      name: 'value',
      label: 'By value',
      selected: false,
      createContentView: function () {
        return new cdb.core.View();
      }
    }];

    var tabPaneOptions = {
      tabPaneOptions: {
        template: tabPaneTemplate,
        tabPaneItemOptions: {
          tagName: 'li',
          className: 'CDB-NavMenu-Item'
        }
      },
      tabPaneItemLabelOptions: {
        tagName: 'button',
        className: 'CDB-NavMenu-Link u-upperCase'
      }
    };

    this._tabPaneView = createTextLabelsTabPane(tabPaneTabs, tabPaneOptions);
    // this._TabPaneView.collection.bind('change:selected', this._updateAddButtonState, this);

    this.$el.append(this._tabPaneView.render().$el);

    return this;
  }
});
