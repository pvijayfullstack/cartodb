var CoreView = require('backbone/core-view');
var template = require('./footer.tpl');

/**
 * Footer view for the add layer modal.
 */
module.exports = CoreView.extend({
  events: {
    'click .js-save': '_save'
  },

  initialize: function (opts) {
    if (!opts.visMetadataModel) throw new Error('visMetadataModel is required');
    if (!opts.onSaveAction) throw new Error('onSaveAction is required');

    this._visMetadataModel = opts.visMetadataModel;
    this._onSaveAction = opts.onSaveAction;
    this._initBinds();
  },

  _initBinds: function () {
    this._visMetadataModel.on('change', this.render, this);
  },

  render: function () {
    this.$el.html(
      template({
        canFinish: this._visMetadataModel.isValid()
      })
    );
    return this;
  },

  _save: function () {
    this._visMetadataModel.isValid() && this._onSaveAction();
  }

});
