var template = require('./source-layer-analysis-view.tpl');

/**
 * View for a analysis source (i.e. SQL query).
 *
 * this.model is expected to be a analysis-definition-node-model and belong to the given layer-definition-model
 */
module.exports = cdb.core.View.extend({

  initialize: function (opts) {
    if (!opts.layerDefinitionModel) throw new Error('layerDefinitionModel is required');

    this._layerDefinitionModel = opts.layerDefinitionModel;
  },

  render: function () {
    this.$el.html(template({
      id: this.model.id,
      tableName: this._layerDefinitionModel.layerTableModel.get('table_name')
    }));

    return this;
  }

});
