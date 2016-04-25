var _ = require('underscore');
var cdb = require('cartodb.js');
var camshaftReference = require('./camshaft-reference');
var AnalysisTableModel = require('./analysis-table-model');

/**
 * Base model for an analysis definition node.
 * May point to one or multiple nodes in turn (referenced by ids).
 */
module.exports = cdb.core.Model.extend({

  initialize: function () {
    if (!this.id) throw new Error('id is required');
  },

  validate: function (attrs) {
    var sourceNames = camshaftReference.getSourceNamesForAnalysisType(this.get('type'));
    var paramNames = camshaftReference.getParamNamesForAnalysisType(attrs.type);

    var errors = _.reduce(paramNames, function (memo, name) {
      var val = this.get(name);
      if (_.contains(sourceNames, name)) {
        var isValid = this.collection.get(val).isValid();
        if (!isValid) {
          memo[name] = _t('data.analysis-definition-node-model.validation.invalid-source');
        }
      } else if (val === undefined) {
        memo[name] = _t('data.analysis-definition-node-model.validation.required');
      }
      return memo;
    }, {}, this);

    if (!_.isEmpty(errors)) {
      return errors;
    }
  },

  /**
   * @override {Backbone.prototype.parse}  flatten the provided analysis data and create source nodes if there are any.
   */
  parse: function (r, opts) {
    var sourceNames = camshaftReference.getSourceNamesForAnalysisType(r.type);

    var parsedParams = _.reduce(r.params, function (memo, val, name) {
      var sourceName = sourceNames[sourceNames.indexOf(name)];

      if (sourceName) {
        this.collection.add(val, opts);
        memo[name] = val.id;
      } else {
        memo[name] = val;
      }

      return memo;
    }, {}, this);

    var parsedOptions = _.reduce(r.options, function (memo, val, name) {
      memo[name] = val;
      return memo;
    }, {}, this);

    if (!this.analysisTableModel && parsedParams.query) {
      this.analysisTableModel = new AnalysisTableModel({}, {
        configModel: opts.configModel
      });

      this.analysisTableModel.set('query', parsedParams.query);
    }

    return _.defaults(
      _.omit(r, 'params', 'options'),
      parsedOptions,
      parsedParams
    );
  },

  /**
   * @param {Boolean} addOptions - Add or not analysis options to the definition
   */
  _serialize: function (addOptions) {
    var sourceNames = camshaftReference.getSourceNamesForAnalysisType(this.get('type'));
    var paramNames = camshaftReference.getParamNamesForAnalysisType(this.get('type'));

    // Undo the parsing of the params previously done in .parse() (when model was created)
    var rawParams = _.reduce(paramNames, function (memo, name) {
      if (_.contains(sourceNames, name)) {
        var sourceId = this.get(name);
        memo[name] = this.collection.get(sourceId).toJSON(addOptions);
      } else {
        memo[name] = this.get(name);
      }

      return memo;
    }, {}, this);

    var json = {
      id: this.get('id'),
      type: this.get('type'),
      params: rawParams
    };

    var optionsAttrs = _.omit(this.attributes, paramNames.concat('id', 'type'));
    if (addOptions && !_.isEmpty(optionsAttrs)) {
      json['options'] = optionsAttrs;
    }
    return json;
  },

  /**
   * @override {Backbone.prototype.toJSON} unflatten the internal structure to the expected nested JSON data structure.
   */
  toJSON: function () {
    return this._serialize();
  },

  /**
   * return all analysis nodes with options
   */
  toJSONWithOptions: function () {
    return this._serialize(true);
  },

  /**
   * @param {Function} cb - Called with cb(error, geometryType)
   */
  asyncGetOutputGeometryType: function (cb) {
    try {
      var geometryType = camshaftReference.getOutputGeometryForType(this.toJSON());
      cb(null, geometryType);
    } catch (err) {
      cb(err);
    }
  },

  destroy: function () {
    this.collection.remove(this);
  },

  getPrimarySourceId: function () {
    var primarySourceName = this.get('primary_source_name') || this._sourceNames()[0];
    return this.get(primarySourceName);
  },

  /**
   * @return {Array} e.g. ['c3', 'b2']
   */
  sourceIds: function () {
    return _.map(this._sourceNames(), function (sourceName) {
      return this.get(sourceName);
    }, this);
  },

  /**
   * @return {Array} e.g. ['polygons_source', 'points_source']
   */
  _sourceNames: function () {
    return camshaftReference.getSourceNamesForAnalysisType(this.get('type'));
  },

  /**
   * @return {String} e.g. 'a'
   */
  getLetter: function () {
    var sourceId = this.get('id');
    return sourceId.match(/^([a-z]+)/)[0];
  }

});
