var _ = require('underscore');
var StyleDefaults = require('./style-defaults');

module.exports = _.defaults({

  DEFAULT_FILL_COLOR: '#C43C24',
  DEFAULT_STROKE_COLOR: '#C43C24',

  _getAggrAttrs: function (geometryType) {
    return {
      aggr_type: 'squares',
      aggr_size: {
        size: {
          fixed: 100
        },
        distance_unit: {
          fixed: 'meters'
        }
      },
      aggr_value: 'count'
    };
  }

}, StyleDefaults);
