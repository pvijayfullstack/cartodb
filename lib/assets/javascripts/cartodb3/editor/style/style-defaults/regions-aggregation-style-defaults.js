var _ = require('underscore');
var SimpleStyleDefaults = require('./simple-style-defaults');

module.exports = _.defaults({

  DEFAULT_FILL_COLOR: '#ECCA8B',
  DEFAULT_STROKE_COLOR: '#9A8F7B',

  _getAggrAttrs: function (geometryType) {
    return {
      aggr_dataset: 'admin0',
      aggr_change: 'manual',
      aggr_value: {
        operation: 'COUNT',
        attribute: ''
      }
    };
  }

}, SimpleStyleDefaults);
