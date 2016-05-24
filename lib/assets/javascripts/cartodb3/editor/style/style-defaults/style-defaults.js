module.exports = {

  DEFAULT_FILL_COLOR: '#FABADA',
  DEFAULT_STROKE_COLOR: '#FFFFFF',
  DEFAULT_LABEL_COLOR: '#AAAAAA',
  DEFAULT_FILL_OPACITY: 0.7,

  generateAttributes: function (geometryType) {
    return {
      fill: null,
      stroke: null,
      blending: null,
      aggregation: {},
      animated: {},
      labels: {}
    };
  }
};
