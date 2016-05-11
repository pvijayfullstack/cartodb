var _ = require('underscore');
var StyleDefaults = require('./style-defaults');

module.exports = _.defaults({

  DEFAULT_FILL_COLOR: '#9DE0AD',
  DEFAULT_STROKE_COLOR: '#FFFFFF',
  DEFAULT_LABEL_COLOR: '#6F808D',
  DEFAULT_FILL_OPACITY: 0.7,

  _getFillAttrs: function (geometryType) {
    var attrs = {
      fill: {
        'color': {
          fixed: this.DEFAULT_FILL_COLOR,
          opacity: this.DEFAULT_FILL_OPACITY
        },
        'image': null
      }
    };

    if (geometryType !== 'polygon') {
      attrs['fill']['size'] = {
        fixed: geometryType === 'point' ? 10 : 2
      };
    }

    return attrs;
  },

  _getStrokeAttrs: function (geometryType) {
    if (geometryType !== 'line') {
      return {
        stroke: {
          'size': {
            fixed: 2
          },
          'color': {
            fixed: this.DEFAULT_STROKE_COLOR,
            opacity: 1
          }
        }
      };
    } else {
      return {};
    }
  },

  _getAnimatedAttrs: function (geometryType) {
    var attrs = {};

    if (geometryType === 'point') {
      attrs = {
        animated: {
          enabled: false,
          attribute: null,
          overlap: false,
          duration: 30,
          steps: 256,
          resolution: 2,
          trails: 2
        }
      };
    }
    return attrs;
  },

  _getLabelsAttrs: function () {
    return {
      labels: {
        enabled: false,
        attribute: null,
        font: 'DejaVu Sans Book',
        fill: {
          'size': {
            fixed: 10
          },
          'color': {
            fixed: this.DEFAULT_LABEL_COLOR,
            opacity: 1
          }
        },
        halo: {
          'size': {
            fixed: 1
          },
          'color': {
            fixed: this.DEFAULT_STROKE_COLOR,
            opacity: 1
          }
        },
        offset: -10,
        overlap: true,
        placement: 'point'
      }
    };
  }
}, StyleDefaults);
