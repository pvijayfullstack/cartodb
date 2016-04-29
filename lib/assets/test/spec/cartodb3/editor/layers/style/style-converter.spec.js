
var StyleGenerator = require('../../../../../../javascripts/cartodb3/editor/style/style-converter');

// 
STYLES = [
  {
    fill: {
      'color': {
        fixed: '#000',
        opacity: 0.4
      },
      'image': null
    }
  }
  ,
  {
    stroke: {
      'size': {
        fixed: 2
      },
      'color': {
        fixed: '#000',
        opacity: 0.4
      }
    }
  },
  {
    fill: {
      'color': {
        fixed: '#000',
        opacity: 0.4
      },
      'image': null
    },
    animated: {
      enabled: true,
      column: 'test',
      overlap: 'linear',
      duration: 30,
      steps: 256,
      resolution: 2,
      trails: 2
    }
  }

];

EXPECTED = [
  { 
    point: '#layer {\nmarker-fill: #000;\nmarker-fill-opacity: 0.4;\n}',
    line: '#layer {\n}',
    polygon: '#layer {\npolygon-fill: #000;\npolygon-opacity: 0.4;\n}'
  },
  { 
    point: '#layer {\nmarker-line-width: 2;\nmarker-line-color: #000;\nmarker-line-opacity: 0.4;\n}',
    line: '#layer {\nline-width: 2;\nline-color: #000;\nline-opacity: 0.4;\n}',
    polygon: '#layer {\nline-width: 2;\nline-color: #000;\nline-opacity: 0.4;\n}',
  }, {
    point: 'Map {\n-torque-frame-count: 256;\n-torque-animation-duration: 30;\n-torque-time-attribute: "test";\n-torque-aggregation-function: "count(1)";\n-torque-resolution: 2;\n-torque-data-aggregation: linear;\n}#layer {\nmarker-fill: #000;\nmarker-fill-opacity: 0.4;\n}',
    line: '#layer {\n}',
    polygon: '#layer {\npolygon-fill: #000;\npolygon-opacity: 0.4;\n}'
  }
]

describe('editor/style/style-converter', function () {
  beforeEach(function () {
  });

  it ("it should generate style", function () {
    for (var i = 0; i < STYLES.length; ++i) {
      expect(StyleGenerator.generateStyle(STYLES[i], 'point').cartoCSS).toBe(EXPECTED[i].point)
      expect(StyleGenerator.generateStyle(STYLES[i], 'line').cartoCSS).toBe(EXPECTED[i].line)
      expect(StyleGenerator.generateStyle(STYLES[i], 'polygon').cartoCSS).toBe(EXPECTED[i].polygon)
    }
  });
});
