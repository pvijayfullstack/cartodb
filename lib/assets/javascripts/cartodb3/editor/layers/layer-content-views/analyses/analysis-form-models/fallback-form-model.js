var camshaftReference = require('../../../../../data/camshaft-reference');
var BaseAnalysisFormModel = require('./base-analysis-form-model');

/**
 * A fallback form model in case the type is not supported (yet).
 */
module.exports = BaseAnalysisFormModel.extend({

  initialize: function () {
    BaseAnalysisFormModel.prototype.initialize.apply(this, arguments);

    this.listenTo(this._analysisSourceOptionsModel, 'change:fetching', this._updateSchema);

    this._updateSchema();
  },

  getTemplate: function () {
    return undefined;
  },

  getTemplateData: function () {
    return {};
  },

  _updateSchema: function () {
    var schema = {};
    var params = camshaftReference.paramsForType(this.get('type'));

    Object.keys(params)
      .forEach(function (name) {
        var param = params[name];
        var label = name + ' (' + param.type + ')';
        var validators = [];
        var isRequired = !param.optional;

        if (isRequired) {
          label += '*';
          validators.push('required');
        }

        switch (param.type) {
          case 'node':
            schema[name] = {
              type: 'Select',
              title: label,
              options: this._getSourceOptionsForSource(name, param.geometry)
            };
            break;
          case 'string':
            schema[name] = {
              type: 'Text',
              title: label,
              validators: validators
            };
            break;
          case 'enum':
            schema[name] = {
              type: 'Select',
              title: label,
              options: param.values.map(function (val) {
                return {
                  val: val,
                  label: val
                };
              }),
              validators: validators
            };
            break;
          case 'number':
            schema[name] = {
              type: 'Number',
              label: label,
              validators: validators
            };
            break;
          case 'boolean':
            schema[name] = {
              type: 'Radio',
              text: label,
              options: [
                {val: 'true', label: 'true'},
                {val: 'false', label: 'false'}
              ],
              validators: validators
            };
            break;
          case 'array':
            schema[name] = {
              type: 'Text',
              title: label,
              validators: validators,
              help: 'Separate values by "||"'
            };
            break;
          default:
            return null;
        }
      }, this);

    this._setSchema(schema);
  },

  /**
   * @param {String} sourceAttrName
   * @param {Array<String>} requiredSimpleGeometryTypes
   */
  _getSourceOptionsForSource: function (sourceAttrName, requiredSimpleGeometryTypes) {
    var currentSource = this.get(sourceAttrName);

    if (this._isFetchingOptions()) {
      return [{
        val: currentSource,
        label: 'loading…'
      }];
    } else {
      // fetched
      var sourceId = this._layerDefinitionModel.get('source');
      return this._analysisSourceOptionsModel
        .getSelectOptions(requiredSimpleGeometryTypes)
        .filter(function (d) {
          // Can't select own layer as source, so exclude it
          return d.val !== sourceId;
        });
    }
  },

  _isFetchingOptions: function () {
    return this._analysisSourceOptionsModel.get('fetching');
  }

});
