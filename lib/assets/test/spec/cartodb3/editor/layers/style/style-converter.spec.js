
var StyleGenerator = require('../../../../../../javascripts/cartodb3/editor/style/style-converter');

// {"type":"aggregation","fill":{"color":{"fixed":"#3B3B58","opacity":0.7},"image":null,"size":{"fixed":10}},"stroke":{"size":{"fixed":2},"color":{"fixed":"#3B3B58","opacity":1}},"aggr_type":"hexabins","aggr_size":{"size":{"fixed":100},"distance":{"fixed":"meters"}},"aggr_value":"count","animated":{"enabled":false,"column":"","overlap":false,"duration":30,"steps":256,"resolution":2,"trails":2},"labels":{"enabled":false,"column":"","font":"DejaVu Sans Book","fill":{"size":{"fixed":10},"color":{"fixed":"#6F808D","opacity":1}},"halo":{"size":{"fixed":1},"color":{"fixed":"#3B3B58","opacity":1}},"offset":-10,"overlap":true,"placement":"point"}}"
FIXTURES = [
{
  style: {
    type: 'simple',
    properties: {
      fill: {
        'color': {
          fixed: '#000',
          opacity: 0.4
        },
        'image': null
      }
    }
  },
  result: {
    point: {
      cartocss: '#layer {\nmarker-fill: #000;\nmarker-fill-opacity: 0.4;\n}'
    },
    line: { 
      cartocss: '#layer {\n}'
    },
    polygon:{ 
      cartocss: '#layer {\npolygon-fill: #000;\npolygon-opacity: 0.4;\n}'
    }
  }
},
{
  style: {
    type: 'simple',
    properties: {
      stroke: {
        'size': {
          fixed: 2
        },
        'color': {
          fixed: '#000',
          opacity: 0.4
        }
      }
    }
  },
  result: {
    point:{ 
      cartocss: '#layer {\nmarker-line-width: 2;\nmarker-line-color: #000;\nmarker-line-opacity: 0.4;\n}'
    },
    line: { 
      cartocss: '#layer {\nline-width: 2;\nline-color: #000;\nline-opacity: 0.4;\n}'
    },
    polygon: { 
      cartocss: '#layer {\nline-width: 2;\nline-color: #000;\nline-opacity: 0.4;\n}'
    }
  }
},
{
  style: {
    type: 'simple',
    properties: {
      fill: {
        'color': {
          fixed: '#000',
          opacity: 0.4
        },
        'image': null
      },
      animated: {
        enabled: true,
        attribute: 'test',
        overlap: 'linear',
        duration: 30,
        steps: 256,
        resolution: 2,
        trails: 2
      }
    }
  },
  result: {
    point:{ 
      cartocss: 'Map {\n-torque-frame-count: 256;\n-torque-animation-duration: 30;\n-torque-time-attribute: "test";\n-torque-aggregation-function: "count(1)";\n-torque-resolution: 2;\n-torque-data-aggregation: linear;\n}#layer {\nmarker-fill: #000;\nmarker-fill-opacity: 0.4;\n}'
    },
    line: { 
      cartocss: '#layer {\n}'
    },
    polygon: { 
      cartocss: '#layer {\npolygon-fill: #000;\npolygon-opacity: 0.4;\n}'
    }
  }
},
{
  style: {
    type: 'simple',
    properties: {
      labels: {
        enabled: true,
        attribute: null,
        font: 'DejaVu Sans Book',
        fill: {
          'size': {
            fixed: 10
          },
          'color': {
            fixed: '#000',
            opacity: 1
          }
        },
        halo: {
          'size': {
            fixed: 1
          },
          'color': {
            fixed: '#111',
            opacity: 1
          }
        },
        offset: -10,
        overlap: true,
        placement: 'point'
      }
    }
  },
  result: {
    point:{ 
      cartocss: "#layer {\n}\n#layer::labels {\n}"
    },
    line:{ 
      cartocss: "#layer {\n}\n#layer::labels {\n}"
    },
    polygon: { 
      cartocss: "#layer {\n}\n#layer::labels {\n}"
    }
  }
},
{
  style: {
    type: 'simple',
    properties: {
      labels: {
        enabled: true,
        attribute: 'test',
        font: 'DejaVu Sans Book',
        fill: {
          'size': {
            fixed: 10
          },
          'color': {
            fixed: '#000',
            opacity: 1
          }
        },
        halo: {
          'size': {
            fixed: 1
          },
          'color': {
            fixed: '#111',
            opacity: 1
          }
        },
        offset: -10,
        overlap: true,
        placement: 'point'
      }
    }
  },
  result: {
    point:{ 
      cartocss: "#layer {\n}\n#layer::labels {\ntext-name: [test];\ntext-face-name: 'DejaVu Sans Book';\ntext-size: 10;\ntext-fill: #000;\ntext-label-position-tolerance: 0;\ntext-halo-radius: 1;\ntext-halo-fill: #111;\ntext-dy: -10;\ntext-allow-overlap: true;\ntext-placement: point;\ntext-placement-type: dummy;\n}"
    },
    line:{ 
      cartocss: "#layer {\n}\n#layer::labels {\ntext-name: [test];\ntext-face-name: 'DejaVu Sans Book';\ntext-size: 10;\ntext-fill: #000;\ntext-label-position-tolerance: 0;\ntext-halo-radius: 1;\ntext-halo-fill: #111;\ntext-dy: -10;\ntext-allow-overlap: true;\ntext-placement: point;\ntext-placement-type: dummy;\n}"
    },
    polygon: { 
      cartocss: "#layer {\n}\n#layer::labels {\ntext-name: [test];\ntext-face-name: 'DejaVu Sans Book';\ntext-size: 10;\ntext-fill: #000;\ntext-label-position-tolerance: 0;\ntext-halo-radius: 1;\ntext-halo-fill: #111;\ntext-dy: -10;\ntext-allow-overlap: true;\ntext-placement: point;\ntext-placement-type: dummy;\n}"
    }
  }
}, {
  style: {
    type: 'hexabins',
    aggregation: {
      aggr_size: {
        size: {
          fixed: 100
        },
        distance_unit: {
          fixed: 'meters'
        }
      },
      aggr_value: {
        operation: 'count',
        attribute: 'test'
      }
    },
    properties: {
      fill: {
        'color': {
          fixed: '#000',
          opacity: 0.4
        }
      }
    }
  },
  result: {
    point: { 
      cartocss: '#layer {\npolygon-fill: #000;\npolygon-opacity: 0.4;\n}',
      sql: "WITH hgrid AS (SELECT CDB_HexagonGrid(ST_Expand(!bbox!, greatest(!pixel_width!,!pixel_height!) * 100), greatest(!pixel_width!,!pixel_height!) * 100) as cell) SELECT hgrid.cell as the_geom_webmercator, count(1) as points_count, count(1)/power( 100 * CDB_XYZ_Resolution(CDB_ZoomFromScale(!scale_denominator!)), 2 ) as points_density, 1 as cartodb_id FROM hgrid, <%= sql %> i where ST_Intersects(i.the_geom_webmercator, hgrid.cell) GROUP BY hgrid.cell"
    }
  }
}
];




describe('editor/style/style-converter', function () {
  beforeEach(function () {
  });

  it ("it should generate style", function () {
    for (var i = 0; i < FIXTURES.length; ++i) {
      expect(StyleGenerator.generateStyle(FIXTURES[i].style, 'point').cartoCSS).toBe(FIXTURES[i].result.point.cartocss)
      if (FIXTURES[i].result.point.sql) {
        expect(StyleGenerator.generateStyle(FIXTURES[i].style, 'point').sql).toBe(FIXTURES[i].result.point.sql)
      }
      if (FIXTURES[i].result.line) {
        expect(StyleGenerator.generateStyle(FIXTURES[i].style, 'line').cartoCSS).toBe(FIXTURES[i].result.line.cartocss)
      }
      if (FIXTURES[i].result.polygon) {
        expect(StyleGenerator.generateStyle(FIXTURES[i].style, 'polygon').cartoCSS).toBe(FIXTURES[i].result.polygon.cartocss)
      }
    }
  });
});
