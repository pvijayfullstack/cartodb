var _ = require('underscore');
var cdb = require('cartodb.js');
var camshaftReference = require('./camshaft-reference');
var QuerySchemaModel = require('./query-schema-model');

/**
 * Base model for an analysis definition node.
 * May point to one or multiple nodes in turn (referenced by ids).
 */
module.exports = cdb.core.Model.extend({

  initialize: function (attrs, opts) {
    if (!this.id) throw new Error('id is required');

    this.querySchemaModel = new QuerySchemaModel(null, {
      configModel: opts.configModel
    });
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

    return _.defaults(
      _.omit(r, 'params', 'options'),
      parsedOptions,
      parsedParams
    );
  },

  /**
   * @override {Backbone.prototype.toJSON} unflatten the internal structure to the expected nested JSON data structure.
   * @param {Object} options
   * @param {Boolean} options.skipOptions - Add or not analysis options to the definition
   */
  toJSON: function (options) {
    options = options || {};

    var sourceNames = camshaftReference.getSourceNamesForAnalysisType(this.get('type'));
    var paramNames = camshaftReference.getParamNamesForAnalysisType(this.get('type'));

    // Undo the parsing of the params previously done in .parse() (when model was created)
    var rawParams = _.reduce(paramNames, function (memo, name) {
      if (_.contains(sourceNames, name)) {
        var sourceId = this.get(name);
        memo[name] = this.collection.get(sourceId).toJSON(options);
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
    if (!options.skipOptions && !_.isEmpty(optionsAttrs)) {
      json['options'] = optionsAttrs;
    }
    return json;
  },

  /**
   * @override {Backbone.prototype.isNew} for this.destroy() to work (not try to send DELETE request)
   */
  isNew: function () {
    return true;
  },

  destroy: function () {
    if (this.querySchemaModel) {
      this.querySchemaModel.destroy();
      this.querySchemaModel = null;
    }

    return cdb.core.Model.prototype.destroy.apply(this, arguments);
  },

  containsNode: function (other) {
    if (!other) return false;
    return this.id === other.id || this._sourcesContains(other);
  },

  _sourcesContains: function (other) {
    var primarySource = this.getPrimarySource();
    var secondarySource = this.getSecondarySource();
    return !!((primarySource && primarySource.containsNode(other)) ||
      (secondarySource && secondarySource.containsNode(other)));
  },

  hasPrimarySource: function () {
    return !!this.getPrimarySource();
  },

  hasSecondarySource: function () {
    return !!this.getSecondarySource();
  },

  getPrimarySource: function () {
    return this.collection.get(this._getPrimarySourceId());
  },

  getSecondarySource: function () {
    // Assumption: there are only 1-2 sources, so secondary is the one that's not the primary
    var primarySourceId = this._getPrimarySourceId();
    var secondarySourceId = _.find(this.sourceIds(), function (sourceId) {
      return sourceId !== primarySourceId;
    });
    return this.collection.get(secondarySourceId);
  },

  /**
   * @return {Array} e.g. ['c3', 'b2']
   */
  sourceIds: function () {
    return _.map(this._sourceNames(), function (sourceName) {
      return this.get(sourceName);
    }, this);
  },

  _getPrimarySourceId: function () {
    var primarySourceName = this.get('primary_source_name') || this._sourceNames()[0];
    return this.get(primarySourceName);
  },

  /**
   * @return {Array} e.g. ['polygons_source', 'points_source']
   */
  _sourceNames: function () {
    return camshaftReference.getSourceNamesForAnalysisType(this.get('type'));
  }

});
