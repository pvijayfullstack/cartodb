var cdb = require('cartodb.js');
var template = require('./aggregation-style-form.tpl');

module.exports = cdb.core.View.extend({

  initialize: function (opts) {
    if (!opts.layerTableModel) throw new Error('layerTableModel is required');
    if (!opts.styleModel) throw new Error('styleModel is required');

    this._layerTableModel = opts.layerTableModel;
    this._styleModel = opts.styleModel;
  },

  render: function () {
    this.$el.html(template());
    return this;
  },

  _initViews: function () {
    // TODO aggregation form
  }

});
