var BaseAnalysisFormModel = require('../base-analysis-form-model.js');
var _ = require('underscore');
var distanceOnMeters = function (type) {
  switch (type) {
    case 'kilometers': return 1000;
    case 'miles': return 1609.34;
    default: return 1;
  }
};

var ANALYSES_MAP = {
  buffer: {
    getAttrs: function () {
      return ['distance', 'radius'];
    },
    getAnalysisAttrs: function () {
      return {
        distance: this.get('distance'),
        radius: parseFloat(this.get('radius')) * distanceOnMeters(this.get('distance'))
      };
    },
    getSchema: function () {
      return {
        source: {
          type: 'Select',
          text: _t('editor.layers.analysis-form.source'),
          options: [ this.get('source') ],
          editorAttrs: { disabled: true }
        },
        type: {
          type: 'Radio',
          text: _t('editor.layers.analysis-form.type'),
          options: [
            {
              val: 'buffer',
              label: _t('editor.layers.analysis-form.distance')
            }, {
              val: 'trade-area',
              label: _t('editor.layers.analysis-form.time')
            }
          ]
        },
        distance: {
          type: 'Radio',
          text: _t('editor.layers.analysis-form.distance'),
          options: [
            {
              val: 'meters',
              label: _t('editor.layers.analysis-form.meters')
            }, {
              val: 'kilometers',
              label: _t('editor.layers.analysis-form.kilometers')
            }, {
              val: 'miles',
              label: _t('editor.layers.analysis-form.miles')
            }
          ]
        },
        radius: {
          type: 'Number',
          label: _t('editor.layers.analysis-form.radius'),
          validators: ['required', {
            type: 'interval',
            min: 0,
            max: 100
          }]
        }
      };
    },
    getDefaults: function () {
      return {
        type: 'buffer',
        distance: 'meters',
        radius: 100
      };
    }
  },
  'trade-area': {
    getAttrs: function () {
      return ['kind', 'time'];
    },
    getAnalysisAttrs: function () {
      return {
        kind: this.get('kind'),
        time: this.get('time')
      };
    },
    getSchema: function () {
      return {
        source: {
          type: 'Select',
          label: _t('editor.layers.analysis-form.source'),
          options: [ this.get('source') ],
          editorAttrs: { disabled: true }
        },
        type: {
          type: 'Radio',
          text: _t('editor.layers.analysis-form.type'),
          options: [
            {
              val: 'buffer',
              label: _t('editor.layers.analysis-form.distance')
            }, {
              val: 'trade-area',
              label: _t('editor.layers.analysis-form.time')
            }
          ]
        },
        kind: {
          type: 'Select',
          title: _t('editor.layers.analysis-form.by'),
          options: [
            {
              val: 'walk',
              label: _t('editor.layers.analysis-form.by-walk')
            }, {
              val: 'drive',
              label: _t('editor.layers.analysis-form.by-car')
            }, {
              val: 'bike',
              label: _t('editor.layers.analysis-form.by-bike')
            }
          ]
        },
        time: {
          type: 'Number',
          label: _t('editor.layers.analysis-form.time'),
          validators: ['required', {
            type: 'interval',
            min: 0,
            max: 100
          }]
        }
      };
    },
    getDefaults: function () {
      return {
        type: 'trade-area',
        kind: 'walk',
        time: 100
      };
    }
  }
};

module.exports = BaseAnalysisFormModel.extend({

  initialize: function (attrs, opts) {
    if (!opts.analysisDefinitionNodeModel) throw new Error('analysisDefinitionNodeModel is required');
    this._analysisDefinitionNodeModel = opts.analysisDefinitionNodeModel;
    this._setDefaults();
    if (this.get('type') === 'buffer') {
      this._adjustRadiusDistance();
    }
    this._setModel();
  },

  _setDefaults: function () {
    var analysisType = this.get('type');
    var defaultAttrs = ANALYSES_MAP[analysisType].getDefaults.bind(this)();
    this.set(_.extend(defaultAttrs, this.attributes));
  },

  _adjustRadiusDistance: function () {
    this.set({
      radius: parseFloat(this.get('radius')) / distanceOnMeters(this.get('distance'))
    }, { silent: true });
  },

  _setModel: function (applyDefaults) {
    var analysisType = this.get('type');
    this._setDefaults();
    this._updateAnalysisNode();
    this.schema = ANALYSES_MAP[analysisType].getSchema.bind(this)();
    this.bind('change', _.debounce(this._onChange.bind(this), 500));
  },

  _unsetModel: function () {
    var previousType = this.previous('type');
    var oldAttrs = ANALYSES_MAP[previousType].getAttrs.bind(this)();

    _.each(oldAttrs, function (attr) {
      this.unset(attr, { silent: true });
      this._analysisDefinitionNodeModel.unset(attr, { silent: true });
    }, this);

    this.unbind(null, null, this);
  },

  _onChangeType: function (newType) {
    this._unsetModel();
    this._analysisDefinitionNodeModel.set('type', newType, { silent: true });
    this._setModel();
    this.trigger('changeSchema', this);
  },

  _onChange: function () {
    if (this.changed.type) {
      this._onChangeType(this.changed.type);
    } else {
      this._updateAnalysisNode();
    }
  },

  _updateAnalysisNode: function () {
    var analysisType = this.get('type');
    this._analysisDefinitionNodeModel.set(ANALYSES_MAP[analysisType].getAnalysisAttrs.bind(this)());
  }

});
