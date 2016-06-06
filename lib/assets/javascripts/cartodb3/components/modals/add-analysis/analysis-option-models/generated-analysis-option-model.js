var _ = require('underscore');
var AnalysisOptionModel = require('./analysis-option-model');
var camshaftReference = require('../../../../data/camshaft-reference');

/**
 * Custom model for point-in-polygon type, to set correct
 */
module.exports = AnalysisOptionModel.extend({

  /**
   * @override {AnalysisOptionModel.getNodeAttrs}
   */
  getFormAttrs: function (sourceId, simpleGeometryTypeInput) {
    var attrs = AnalysisOptionModel.prototype.getFormAttrs.apply(this, arguments);

    this._removeSourceIfThereAreMultipleSources(attrs);

    return attrs;
  },

  _removeSourceIfThereAreMultipleSources: function (attrs) {
    var params = camshaftReference.paramsForType(attrs.type);
    var sourceCount = _.reduce(Object.keys(params), function (memo, name) {
      if (params[name].type === 'node') {
        memo++;
      }
      return memo;
    }, 0);

    if (sourceCount > 1) {
      delete attrs.source;
    }
  }

});
