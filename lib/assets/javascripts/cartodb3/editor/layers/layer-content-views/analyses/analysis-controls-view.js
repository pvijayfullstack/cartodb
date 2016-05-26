var cdb = require('cartodb.js');
var template = require('./analysis-controls.tpl');

/**
 * View representing the apply button for a form
 */
module.exports = cdb.core.View.extend({

  className: 'Toggle-bar',

  events: {
    'click .js-apply': '_onApplyClicked'
  },

  initialize: function (opts) {
    if (!opts.formModel) throw new Error('formModel is required');
    if (!opts.analysisDefinitionNodesCollection) throw new Error('analysisDefinitionNodesCollection is required');

    this._formModel = opts.formModel;
    this._analysisDefinitionNodesCollection = opts.analysisDefinitionNodesCollection;

    this._formModel.on('change:errors', this.render, this);
    this.add_related_model(this._formModel);
  },

  render: function () {
    this.$el.html(this._html());
    return this;
  },

  _html: function () {
    return template({
      isDisabled: !this._isFormValid()
    });
  },

  _onApplyClicked: function () {
    if (!this._isFormValid()) return;

    var analysisDefinitionNodesCollection = this._analysisDefinitionNodesCollection;
    this._formModel.save(analysisDefinitionNodesCollection);
  },

  _isFormValid: function () {
    return !this._formModel.get('errors');
  }

});
