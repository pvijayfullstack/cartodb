
describe("cartodb.models.Map", function() {

  var map, layers;
  beforeEach(function() {
    map = new cdb.admin.Map();
    layers = new cdb.admin.Layers();
  });

  it("should clone", function() {
    var layer = new cdb.geo.CartoDBLayer();
    layers.add(layer);
    var copy = layers.clone();
    expect(copy.size()).toEqual(layers.size());
    var a = _.clone(layers.models[0].attributes);
    delete a.id;
    expect(copy.models[0].attributes).toEqual(a);
    expect(copy.get('id')).toEqual(undefined);
  });

  it("should not change bounds according to base layer", function() {
    var layer = new cdb.geo.CartoDBLayer({
      maxZoom: 8,
      minZoom: 7,
      type: 'Tiled',
      urlTemplate: 'x',
      base_type: 'x'
    });
    map.addLayer(layer);
    expect(map.get('maxZoom')).toEqual(8);
    expect(map.get('minZoom')).toEqual(7);
    var layerbase = new cdb.geo.CartoDBLayer({
      maxZoom: 10,
      minZoom: 9,
      type: 'Tiled',
      urlTemplate: 'y',
      base_type: 'y'
    });
    sinon.stub(layerbase, "save").yieldsTo("success");
    map.setBaseLayer(layerbase);
    expect(map.get('maxZoom')).toEqual(10);
    expect(map.get('minZoom')).toEqual(9);
  });

  it("should set a new attribution after change base layer", function() {
    var old = new cdb.geo.CartoDBLayer({ attribution: 'CartoDB1.0', type: 'Tiled', urlTemplate: 'x', base_type: 'x' });
    map.setBaseLayer(old);
    var old_attribution = map.get('attribution');

    var base = new cdb.geo.CartoDBLayer({ attribution: 'CartoDB2.0', type: 'Tiled', urlTemplate: 'y', base_type: 'y' });
    sinon.stub(base, "save").yieldsTo("success");
    var r = map.setBaseLayer(base);
    var new_attribution = map.get('attribution');

    expect(old_attribution[0]).not.toEqual(new_attribution[0]);
  });

  it("shouldn't set base layer if the old base layer is the same", function() {
    var old = new cdb.geo.TileLayer({ type: 'Tiled', urlTemplate: 'x', base_type: 'x' })
      , opts = { alreadyAdded: function(){ console.log("base layer already added"); }};

    var added = false;
    map.bind('savingLayersFinish', function() {
      added = true;
    });

    expect(map.setBaseLayer(old)).not.toBeFalsy();
    expect(map.setBaseLayer(old, opts)).toBeFalsy();
    expect(added).toEqual(true);
  });

  it("should get 0 layers when type is not specified", function() {
    expect(map.layers.getLayersByType()).toBe(0);
    expect(map.layers.getLayersByType('')).toBe(0);
  });

  it("should get the number of CartoDB layers", function() {
    var lyr_1 = new cdb.geo.CartoDBLayer({ urlTemplate:'x', base_type: "x" });
    var lyr_2 = new cdb.geo.CartoDBLayer({ urlTemplate:'y', base_type: "y" });
    map.addLayer(lyr_1);
    map.addLayer(lyr_2);
    expect(map.layers.getLayersByType('CartoDB').length).toBe(2);
  });

  it("should get the number of Tiled layers", function() {
    var lyr_1 = new cdb.geo.CartoDBLayer({ urlTemplate:'x', base_type: "x" });
    var lyr_2 = new cdb.geo.CartoDBLayer({ urlTemplate:'y', base_type: "y" });
    var lyr_3 = new cdb.geo.CartoDBLayer({ maxZoom: 8, minZoom: 7, type: 'Tiled', urlTemplate: 'x', base_type: 'x' });
    map.addLayer(lyr_1);
    map.addLayer(lyr_2);
    map.addLayer(lyr_3);
    expect(map.layers.getLayersByType('Tiled').length).toBe(1);
  });

  it("shouldn't get any layer if this layer type doesn't exist", function() {
    var lyr_1 = new cdb.geo.CartoDBLayer({ urlTemplate:'x', base_type: "x" });
    var lyr_2 = new cdb.geo.CartoDBLayer({ urlTemplate:'y', base_type: "y" });
    var lyr_3 = new cdb.geo.CartoDBLayer({ maxZoom: 8, minZoom: 7, type: 'Tiled', urlTemplate: 'x', base_type: 'x' });
    map.addLayer(lyr_1);
    map.addLayer(lyr_2);
    map.addLayer(lyr_3);
    expect(map.layers.getLayersByType('Jamon').length).toBe(0);
  });

  it("should set base layer", function() {
    var old = new cdb.geo.CartoDBLayer({ urlTemplate:'x', base_type: "x" });
    map.addLayer(old);
    var layer    = new cdb.geo.CartoDBLayer({ urlTemplate:'y', base_type: "y" });
    map.addLayer(layer);
    var base = new cdb.geo.CartoDBLayer({ urlTemplate:'z', base_type: "z" });

    sinon.stub(base, "save").yieldsTo("success");
    var r = map.setBaseLayer(base);
    expect(r).toEqual(base);
    expect(map.layers.at(0)).toEqual(base);
  });

  it("should change layers 'map_id' attribution if map id changes", function() {
    var old = new cdb.geo.CartoDBLayer({});
    map.setCenter([1,0]);
    map.addLayer(old);

    old.sync = function(a, b, opts) {
      opts.success({
        map_id: 68
      }, 200);
    }

    map.set('id', 68);
    expect(map.layers.models[0].url().indexOf('/maps/68/layers') != -1).toEqual(true);
  });

  it("should trigger change:dataLayer when datalayer changes", function() {
    var s = {
      changed: function() {}
    };
    spyOn(s, 'changed');
    map.bind('change:dataLayer', s.changed);
    map.addDataLayer(new cdb.geo.MapLayer());
    expect(s.changed).toHaveBeenCalled();
  });

  it("should trigger change:dataLayer when 2 layers are added", function() {
    var s = {
      changed: function() {}
    };
    spyOn(s, 'changed');
    map.bind('change:dataLayer', s.changed);
    map.layers.add(new cdb.geo.MapLayer());
    map.layers.add(new cdb.geo.MapLayer());
    expect(s.changed).toHaveBeenCalled();
  });

  it("should trigger change:dataLayer when is reset with two layers", function() {
    var s = {
      changed: function() {}
    };
    spyOn(s, 'changed');
    map.bind('change:dataLayer', s.changed);
    map.layers.reset([
      new cdb.geo.MapLayer(),
      new cdb.geo.MapLayer()
    ]);
    expect(s.changed).toHaveBeenCalled();
  });

  it('should change provider', function() {
    spyOn(map, 'save');
    map.changeProvider('googlemaps');
    expect(map.save).toHaveBeenCalled();
  });

  it('should not change provider if it is the same', function() {
    spyOn(map, 'save');
    map.changeProvider('leaflet');
    expect(map.save).not.toHaveBeenCalled();
  });

  it('should change the base layer', function() {
    spyOn(map, 'save');
    spyOn(map, 'setBaseLayer');
    sinon.stub(map, 'save', function(data, o) {
      o.success();
    });
    map.changeProvider('leaflet', new cdb.geo.MapLayer());
    expect(map.setBaseLayer).toHaveBeenCalled();
  });

  it('should notice on fail', function() {
    s = sinon.spy();
    spyOn(map, 'setBaseLayer');
    map.bind('notice', s);
    sinon.stub(map, 'save', function(data, o) {
      o.error(null, {responseText: '{"errors":[]}'});
    });
    map.changeProvider('gmaps', new cdb.geo.MapLayer());
    expect(map.setBaseLayer).not.toHaveBeenCalled();
    expect(s.called).toEqual(true);
  });

  /*describe("layer", function() {
    it("parse", function() {
        var layer = new cdb.geo.MapLayer({kind: 'carto', options: {}});
        expect(layer.get('type')).toEqual('CartoDB');
        layer = new cdb.geo.MapLayer({kind: 'tiled', options: {}});
        expect(layer.get('type')).toEqual('Tiled');
    });
  });*/

  describe("layers", function() {
    it("should order with cartodb layers on top of tiled", function() {
      var layers = new cdb.admin.Layers();
      layers.reset([
        new cdb.geo.TileLayer(),
        new cdb.geo.CartoDBLayer()
      ]);
      expect(layers.at(0).get('type')).toEqual('Tiled');
      expect(layers.at(1).get('type')).toEqual('CartoDB');

      layers.reset([
        new cdb.geo.CartoDBLayer(),
        new cdb.geo.TileLayer()
      ]);
      expect(layers.at(0).get('type')).toEqual('Tiled');
      expect(layers.at(1).get('type')).toEqual('CartoDB');

      layers.reset([
        {kind: 'carto', options: {}},
        {kind: 'tiled', options: {}}
      ], { parse: true  });
      expect(layers.at(0).get('type')).toEqual('Tiled');
      expect(layers.at(1).get('type')).toEqual('CartoDB');
    });

    it("should order with torque layers on top of cartodb", function() {
      var layers = new cdb.admin.Layers();
      layers.reset([
        new cdb.geo.TorqueLayer(),
        new cdb.geo.TileLayer()
      ]);
      expect(layers.at(0).get('type')).toEqual('Tiled');
      expect(layers.at(1).get('type')).toEqual('torque');
    });

    it("should add layers on top", function() {
      var layers = new cdb.admin.Layers();
      layers.reset([
        new cdb.geo.TileLayer(),
        new cdb.geo.CartoDBLayer()
      ]);
      var t = new cdb.geo.TorqueLayer();
      t.unset('order');
      layers.add(t);
      expect(layers.at(2).get('type')).toEqual('torque');
    });

    it("should not allow to insert more than one torque layer", function() {
      var s = sinon.spy()
      layers.bind('error:torque', s);
      layers.add(new cdb.geo.TorqueLayer());
      expect(s.called).toEqual(false);
      layers.add(new cdb.geo.TorqueLayer());
      expect(layers.size(), 1);
      expect(s.called).toEqual(true);
    });


    it("should insert cartodb layers before torque layers", function() {
      var layers = new cdb.admin.Layers();
      layers.reset([
        new cdb.geo.TileLayer(),
        new cdb.geo.TorqueLayer(),
      ]);
      var c = new cdb.geo.CartoDBLayer();
      c.unset('order');
      layers.add(c);
      expect(layers.at(0).get('type')).toEqual('Tiled');
      expect(layers.at(1).get('type')).toEqual('CartoDB');
      expect(layers.at(2).get('type')).toEqual('torque');
    });

    it("should create the right type", function() {
      var layers = new cdb.admin.Layers();
      layers.reset([
        {kind: 'carto', options: {}}
        //{kind: 'tiled', options: {}}
      ], { parse: true  });
      //expect(typeof(layers.at(0))).toEqual(cdb.geo.TileLayer);
      expect(layers.at(0).undoHistory).not.toEqual(undefined);
    });

    it("should remove api key in toJSON", function() {
      var layer = new cdb.admin.CartoDBLayer();
      layer.set({ extra_params: {
        'map_key': 'test',
        'api_key': 'test',
        'dummy': 'test2'
      }});
      expect(_.keys(layer.toJSON().options.extra_params).length).toEqual(1);

    });

    it("should include infowindow in toJSON", function() {
      var layer = new cdb.admin.CartoDBLayer();
      layer.set({
        infowindow: 'test'
      });
      expect(layer.toJSON().infowindow).toEqual('test');
    });

    it("should remove missing fields before save", function() {
      var layer = new cdb.admin.CartoDBLayer({ id: 1});
      spyOn(layer, 'save')
      layer.table = TestUtil.createTable("test", [
        ['test', 'number'],
        ['test2', 'string']
      ])
      runs(function() {
        // addd a field not in the schema
        layer.infowindow.addField('rambo')
        layer.infowindow.addField('test')
        layer.infowindow.addField('test2')
      });
      waits(1000);
      runs(function() {
        expect(layer.save).toHaveBeenCalled()
        expect(layer.save.calls.length).toEqual(1)
        var fieldNames = _.pluck(layer.save.calls[0].args[0].infowindow.fields, 'name')
        expect(_.contains(fieldNames,'rambo')).toEqual(false);
        expect(_.contains(fieldNames,'test')).toEqual(true);
        expect(_.contains(fieldNames,'test2')).toEqual(true);
      });
    });

    it("should add api key when parse", function() {
      var layer = new cdb.admin.CartoDBLayer();
      layer.set({ extra_params: {
        'map_key': 'test',
        'api_key': 'test',
        'dummy': 'test2'
      }});

      var a = layer.parse({
        type: 'Layer::Carto',
        options: {
          extra_params: {
          'dummy': 'test2'
          }
        }
      });

      expect(a.extra_params.map_key).not.toEqual(undefined);

    });

    it("should add metadata when parse", function() {
      var layer = new cdb.admin.CartoDBLayer();
      layer.set({ 
        wizard_properties: {
          properties: {
            metadata: 'test'
          }
        }
      }, { silent: true });

      var a = layer.parse({
        type: 'Layer::Carto',
        options: {
          wizard_properties: {
            properties: { 'dummy': 'test2' }
          }
        }
      });

      expect(a.wizard_properties.properties.metadata).toEqual('test');

    });

    it("should get layer def", function() {
      var layers = new cdb.admin.Layers();
      layers.reset([
        new cdb.geo.TileLayer(),
        new cdb.admin.CartoDBLayer({ tile_style: 'test1', query: 'sql1', interactivity: 'int1', visible: true}),
        new cdb.admin.CartoDBLayer({ tile_style: 'test2', query: 'sql2', interactivity: 'int2', visible: true}),
        new cdb.admin.CartoDBLayer({ tile_style: 'test3', query: 'sql3', interactivity: 'int3', visible: false}),
        new cdb.admin.CartoDBLayer({ tile_style: 'test4', query: 'select * from jaja', query_wrapper: "select i from (<%= sql %>)", interactivity: 'int3', visible: true})
      ]);

      expect(layers.getLayerDef()).toEqual({
        version:'1.0.1',
        layers: [
          {
            type: "cartodb",
            options: {
              sql: 'sql1',
              cartocss: 'test1',
              cartocss_version: '2.1.1',
              interactivity: 'int1'
            }
          },
          {
            type: "cartodb",
            options: {
              sql: 'sql2',
              cartocss: 'test2',
              cartocss_version: '2.1.1',
              interactivity: 'int2'
            }
          },
          {
            type: "cartodb",
            options: {
              sql: 'select i from (select * from jaja)',
              cartocss: 'test4',
              cartocss_version: '2.1.1',
              interactivity: 'int3'
            }
          }
       ]
      })
    });


    it("should get layer def index", function() {
      var layers = new cdb.admin.Layers();
      var layer = new cdb.admin.CartoDBLayer({ tile_style: 'test2', query: 'sql2', interactivity: 'int2', visible: true});
      var layer2 = new cdb.admin.CartoDBLayer({ tile_style: 'test3', query: 'sql3', interactivity: 'int3', visible: true});
      layers.reset([
        new cdb.geo.TileLayer(),
        new cdb.admin.CartoDBLayer({ tile_style: 'test1', query: 'sql1', interactivity: 'int1', visible: false}),
        layer,
        layer2
      ]);

      expect(layers.getLayerDefIndex(layer)).toEqual(0);
      expect(layers.getLayerDefIndex(layer2)).toEqual(1);
    });


    it("should get properly the number of data layers", function() {
      var layers = new cdb.admin.Layers();
      var tiled = new cdb.geo.TileLayer({ type: 'Tiled', urlTemplate: 'x', base_type: 'x' });
      var layer = new cdb.admin.CartoDBLayer({ tile_style: 'test2', query: 'sql2', interactivity: 'int2', visible: true});
      var layer1 = new cdb.admin.CartoDBLayer({ tile_style: 'test1', query: 'sql1', interactivity: 'int1', visible: false});
      var layer2 = new cdb.admin.CartoDBLayer({ tile_style: 'test3', query: 'sql3', interactivity: 'int3', visible: true});
      var layer3 = new cdb.geo.TorqueLayer();
      
      layers.reset([ tiled, layer, layer1, layer2 ]);
      expect(layers.getTotalDataLayers()).toBe(3);

      layers.reset([layer1, layer3]);
      expect(layers.getTotalDataLayers()).toBe(2);

      layers.reset([tiled, layer3]);
      expect(layers.getTotalDataLayers()).toBe(1);

      layers.reset([tiled]);
      expect(layers.getTotalDataLayers()).toBe(0);

      layers.reset([tiled, layer, layer1, layer2, layer3 ]);
      expect(layers.getTotalDataLayers()).toBe(4);
    })

    it("should get properly the number of data layers with legend applied", function() {
      var layers = new cdb.admin.Layers();
      var tiled = new cdb.geo.TileLayer({ type: 'Tiled', urlTemplate: 'x', base_type: 'x' });
      var layer = new cdb.admin.CartoDBLayer({ tile_style: 'test2', query: 'sql2', interactivity: 'int2', visible: true, legend: { type: '' } });
      var layer1 = new cdb.admin.CartoDBLayer({ tile_style: 'test1', query: 'sql1', interactivity: 'int1', visible: false, legend: { type: 'custom' }});
      var layer2 = new cdb.admin.CartoDBLayer({ tile_style: 'test3', query: 'sql3', interactivity: 'int3', visible: true, legend: {  }});
      var layer3 = new cdb.geo.TorqueLayer({ legend: { type: 'torque' } });
      
      layers.reset([ tiled, layer, layer1, layer2 ]);
      expect(layers.getTotalDataLegends()).toBe(1);

      layers.reset([layer1, layer3]);
      expect(layers.getTotalDataLegends()).toBe(2);

      layers.reset([tiled, layer3]);
      expect(layers.getTotalDataLegends()).toBe(1);

      layers.reset([tiled]);
      expect(layers.getTotalDataLegends()).toBe(0);

      layers.reset([tiled, layer, layer1, layer2, layer3 ]);
      expect(layers.getTotalDataLegends()).toBe(2);

      layers.reset([ layer, layer2 ]);
      expect(layers.getTotalDataLegends()).toBe(0);
    })
  });


  describe('CartoDBLayer', function() {
    var layer;
    beforeEach(function() {
      layer  = new cdb.admin.CartoDBLayer();
      layer.set('tile_style_custom', true);
    });
    afterEach(function() {
      delete localStorage['test_storage_'+layer.get('table_name')]
    })

    it("should set order on parse", function() {
      var a = layer.parse({
        id: 1,
        order: 1001,
        options: {}
      });
      expect(a.order).toEqual(1001);
      expect(a.id).toEqual(1);

    });

    it("should contain a default wizard type", function() {
      layer.sync = function() {}
      layer.table.set('geometry_types', ['st_point']);
      expect(layer.wizard_properties.get('type')).toEqual('polygon');
    })

    it("should initialize history", function() {
      layer.initHistory('test');
      expect(layer.get('test_history').length).toEqual(0);
      expect(layer.test_history_position).toEqual(0);
    })

    it("should be able to update history", function() {
      layer.initHistory('test');
      layer.addToHistory('test', 'test1');
      expect(layer.get('test_history').length).toEqual(1);
      expect(layer.get('test_history')[0]).toEqual('test1');
    })

    it("should trim the history when limit is reached", function() {
      layer.MAX_HISTORY_TEST = 3
      layer.initHistory('test');
      layer.addToHistory('test', 'test1');
      layer.addToHistory('test', 'test2');
      layer.addToHistory('test', 'test3');
      layer.addToHistory('test', 'test4');
      expect(layer.get('test_history').length).toEqual(3);
      expect(layer.get('test_history')[0]).toEqual('test2');
    });

    it("should save on localStorage the history when limit is reached", function() {
      layer.MAX_HISTORY_TEST = 3
      layer.initHistory('test');
      layer.addToHistory('test', 'test1');
      layer.addToHistory('test', 'test2');
      layer.addToHistory('test', 'test3');
      layer.addToHistory('test', 'test4');
      expect(localStorage.getItem('test_storage_'+layer.get('table_name'))).toEqual('["test1"]');
    });

    it("should detect if it's on the last history position", function() {
      layer.initHistory('test');
      layer.addToHistory('test', 'test1');
      layer.addToHistory('test', 'test2');
      expect(layer.isHistoryAtLastPosition('test')).toBeTruthy();
    })

    it("should detect if it's not on the last history position after browse", function() {
      layer.initHistory('test');
      layer.addToHistory('test', 'test1');
      layer.addToHistory('test', 'test2');
      layer.undoHistory('test');
      expect(layer.isHistoryAtLastPosition('test')).toBeFalsy();
    })
    it("should detect if it's on the last history position after browse and back", function() {
      layer.initHistory('test');
      layer.addToHistory('test', 'test1');
      layer.addToHistory('test', 'test2');
      layer.undoHistory('test');
      layer.redoHistory('test');
      expect(layer.isHistoryAtLastPosition('test')).toBeTruthy();
    })


    it("should detect if it's not the first history position", function() {
      layer.initHistory('test');
      layer.addToHistory('test', 'test1');
      layer.addToHistory('test', 'test2');
      expect(layer.isHistoryAtFirstPosition('test')).toBeFalsy();
    })

    it("should detect if it's on the first history position", function() {
      layer.initHistory('test');
      layer.addToHistory('test', 'test1');
      layer.addToHistory('test', 'test2');
      layer.undoHistory('test')
      expect(layer.isHistoryAtFirstPosition('test')).toBeTruthy();
    })


    it("should detect if it's not the first history position when there's local storage and user has browse after 0 pos", function() {
      layer.MAX_HISTORY_TEST = 3
      layer.initHistory('test');
      layer.addToHistory('test', 'test1');
      layer.addToHistory('test', 'test2');
      layer.addToHistory('test', 'test3');
      layer.addToHistory('test', 'test4');
      expect(layer.isHistoryAtFirstPosition('test')).toBeFalsy();
    })

    it("should detect if it's not the first history position when there's local storage and user has browse after 0 pos", function() {
      layer.MAX_HISTORY_TEST = 3
      layer.initHistory('test');
      layer.addToHistory('test', 'test1');
      layer.addToHistory('test', 'test2');
      layer.addToHistory('test', 'test3');
      layer.addToHistory('test', 'test4');
      layer.undoHistory('test')
      layer.undoHistory('test')
      expect(layer.isHistoryAtFirstPosition('test')).toBeFalsy();
    })


    it("should detect if it's on the first history position when there's local storage", function() {
      layer.MAX_HISTORY_TEST = 3
      layer.initHistory('test');
      layer.addToHistory('test', 'test1');
      layer.addToHistory('test', 'test2');
      layer.addToHistory('test', 'test3');
      layer.addToHistory('test', 'test4');
      layer.undoHistory('test')
      layer.undoHistory('test')
      layer.undoHistory('test')
      expect(layer.isHistoryAtFirstPosition('test')).toBeTruthy();
    })

    it("should not save a new style if it's the same than previous one", function() {
      layer.initHistory('test');
      layer.addToHistory('test', 'test1');
      layer.addToHistory('test', 'test1');
      expect(layer.get('test_history').length).toEqual(1);
    });

    it("should undo tile_style history", function() {
      layer.initHistory('tile_style');
      layer.addToHistory('tile_style', 'test1');
      layer.addToHistory('tile_style', 'test2');
      layer.addToHistory('tile_style', 'test3');
      layer.set({ test: 'test3'});

      var data = layer.undoHistory('tile_style');
      expect(layer.getCurrentHistoryPosition('tile_style')).toEqual('test2');
    });


    it("should undo history and get it from localStorage", function() {
      layer.MAX_HISTORY_TEST = 3
      layer.initHistory('test');
      layer.addToHistory('test', 'test1');
      layer.addToHistory('test', 'test2');
      layer.addToHistory('test', 'test3');
      layer.addToHistory('test', 'test4');

      var data = layer.undoHistory('test');
      data = layer.undoHistory('test');
      data = layer.undoHistory('test');

      expect(layer.getCurrentHistoryPosition('test')).toEqual('test1');
    });


    it("should return first history if you undo more than the length", function() {
      layer.MAX_HISTORY_TEST = 3
      layer.initHistory('test');
      layer.addToHistory('test', 'test1');
      layer.addToHistory('test', 'test2');
      layer.addToHistory('test', 'test3');

      var data = layer.undoHistory('test');
      data = layer.undoHistory('test');
      data = layer.undoHistory('test');

      expect(layer.getCurrentHistoryPosition('test')).toEqual('test1');
    });

    it("should return first history if you undo more than the length also from localStorage", function() {
      layer.MAX_HISTORY_TEST = 3
      layer.initHistory('test');
      layer.addToHistory('test', 'test1');
      layer.addToHistory('test', 'test2');
      layer.addToHistory('test', 'test3');
      layer.addToHistory('test', 'test4');

      var data = layer.undoHistory('test');
      data = layer.undoHistory('test');
      data = layer.undoHistory('test');
      data = layer.undoHistory('test');
      data = layer.undoHistory('test');
      data = layer.undoHistory('test');

      expect(layer.getCurrentHistoryPosition('test')).toEqual('test1');
    });

    it("should redo tile_style history", function() {
      layer.initHistory('tile_style');
      layer.addToHistory('tile_style', 'test1');
      layer.addToHistory('tile_style', 'test2');
      layer.addToHistory('tile_style', 'test3');
      layer.set({ test: 'test3'});

      layer.undoHistory('tile_style');
      layer.redoHistory('tile_style');
      expect(layer.getCurrentHistoryPosition('tile_style')).toEqual('test3');
    });


    it("should undo to localstorage and redo to persisted history flawless", function() {
      layer.MAX_HISTORY_TEST = 3
      layer.initHistory('test');
      layer.addToHistory('test', 'test1');
      layer.addToHistory('test', 'test2');
      layer.addToHistory('test', 'test3');
      layer.addToHistory('test', 'test4');
      layer.addToHistory('test', 'test5');

      var data = layer.undoHistory('test'); //test4
      data = layer.undoHistory('test');//test3
      data = layer.undoHistory('test');//test2
      data = layer.undoHistory('test');//test1
      data = layer.redoHistory('test');//test2
      data = layer.redoHistory('test');//test3
      data = layer.redoHistory('test');//test4
      data = layer.redoHistory('test');//test5

      expect(layer.getCurrentHistoryPosition('test')).toEqual('test5');
    });

    it("should not save more than MAX_HISTORY_TILE_STYLE", function() {
      for(var i = 0; i < layer.MAX_HISTORY_TILE_STYLE + 1; ++i) {
        layer.addToHistory('tile_style', 'test' + i);
      }
      expect(layer.get('tile_style_history').length).toEqual(layer.MAX_HISTORY_TILE_STYLE);

    });

    it("should change state", function() {
      var sqlView = new cdb.admin.SQLViewData();
      layer.sync = function() {}
      layer.bindSQLView(sqlView);
      expect(layer.getCurrentState()).toEqual('success');
      sqlView.trigger('error');
      expect(layer.getCurrentState()).toEqual('error');
      sqlView.trigger('reset');
      expect(layer.getCurrentState()).toEqual('success');
    })

    it("should bind to sqlView", function() {
      var sqlView = new cdb.admin.SQLViewData();
      layer.bindSQLView(sqlView);
      layer.set('query', 'test');
      spyOn(layer, 'save')
      sqlView.trigger('error');
      expect(layer.save).toHaveBeenCalledWith({query: null}, {silent: true});

      sqlView.modify_rows = true;
      layer.set('query', 'test');
      spyOn(layer, 'invalidate');
      sqlView.trigger('reset');
      expect(layer.get('query')).toEqual(null);
      expect(layer.invalidate).toHaveBeenCalled();

      sqlView.modify_rows = false;
      layer.set('query', 'test');
      sqlView.options.set('sql', 'testsql')
      sqlView.trigger('reset');
      expect(layer.save).toHaveBeenCalledWith({query: 'testsql' })
      sqlView.add({ cartodb_id: 1, test: 2})
      sqlView.trigger('reset');
      expect(layer.save).toHaveBeenCalledWith({query: 'testsql' });
    })

    it("should disable interaction when the query has no cartodb_id", function() {
      spyOn(layer, 'save');
      layer.set({ interactivity: 'cartodb_id' });
      layer.table.set({
        schema: [
          ['the_geom_webmercator', 'geom']
        ]
      });
      expect(layer.save).toHaveBeenCalledWith({ interactivity: null });
      layer.set({ interactivity: null });
      layer.save.reset();
      layer.table.set({
        schema: [
          ['cartodb_id', 'number'],
          ['the_geom_webmercator', 'geom']
        ]
      });
      expect(layer.save).toHaveBeenCalledWith({interactivity: 'cartodb_id'});
    });

    it("should apply sql when it's binded to sqlView", function() {
      var sql;
      layer.set('query', sql = 'select * from table');
      var sqlView = new cdb.admin.SQLViewData();
      layer.bindSQLView(sqlView);
      expect(sqlView.getSQL()).toEqual(sql);
    });

    it("should define sqlView when binds it", function() {
      var sqlView = new cdb.admin.SQLViewData();
      layer.bindSQLView(sqlView);
      expect(layer.sqlView).toBeDefined();
    });

    it("should apply a sql to the sqlView if it was previously set in the layer", function() {
      var expected = false;
      layer.set("query", "SELECT * FROM table_test");
      layer.bind("applySQLView", function() {
        expected = true;
      });
      layer.bindSQLView(new cdb.admin.SQLViewData());
      expect(expected).toBeTruthy();
    });

    it("should apply a query", function() {
      var sqlView = new cdb.admin.SQLViewData();
      layer.bindSQLView(sqlView);
      spyOn(layer.sqlView, 'setSQL');
      spyOn(layer.sqlView, 'fetch');
      layer.applySQLView("SELECT * FROM test");
      expect(layer.query_history_position).toBe(0);
      expect(layer.get('query_history').length).toBe(1);
      expect(layer.sqlView.setSQL).toHaveBeenCalledWith("SELECT * FROM test", {silent:true, sql_source: null});
      expect(layer.sqlView.fetch).toHaveBeenCalled();

      layer.applySQLView("SELECT * FROM test where cartodb_id = 1234", { sql_source: 'rambo' });
      expect(layer.sqlView.setSQL).toHaveBeenCalledWith("SELECT * FROM test where cartodb_id = 1234", {silent:true, sql_source: 'rambo'});
    });

    it("resetQuery should set interactivity to cartodb_id", function() {

      layer.set('interactivity', null);
      spyOn(layer, 'save')
      layer.resetQuery();
      expect(layer.save).toHaveBeenCalledWith({
        query: undefined,
        sql_source: null,
        interactivity: 'cartodb_id'
      });

    });

    it("should remove a query", function() {
      layer.sync = function() {}
      var sqlView = new cdb.admin.SQLViewData();
      layer.bindSQLView(sqlView);
      spyOn(layer, 'resetQuery');
      spyOn(layer.sqlView, 'fetch');
      layer.applySQLView("SELECT * FROM test WHERE cartodb_id > 10");
      layer.clearSQLView();

      expect(layer.get('query_history').length).toBe(2);
      expect(layer.table.isInSQLView()).toBeFalsy();
      expect(layer.resetQuery).toHaveBeenCalled();
    });
    
    it("when style is updated the forms should be updated", function() {
      // generate some carto to test
      layer.sync = function() {}
      layer.table.set('geometry_types', ['st_polygon']);
      var gen = new cdb.admin.CartoStyles({ table: layer.table });
      gen.attr('polygon-fill', '#FFEE00');
      var custom_style = gen.get('style') + "\n #table::wadus { }";
      layer.sync = function() {}
      layer.wizard_properties.active('polygon');
      layer.set({
        tile_style: custom_style,
        tile_style_custom: true
      });
      expect(layer.wizard_properties.get('polygon-fill')).toEqual('#ffee00');
    });

  });


});

describe("Infowindow", function() {
  it("should remove missing fields", function() {
    info = new cdb.geo.ui.InfowindowModel();
    info.addField('test').addField('test2');
    info.removeMissingFields(['test2', 'uhuh']);
    expect(info.containsField('test')).toEqual(false)
    expect(info.containsField('uhuh')).toEqual(false)
    expect(info.containsField('test2')).toEqual(true);
  });

  it("should add new fields and remove missing fields", function() {
    info = new cdb.geo.ui.InfowindowModel();
    info.addField('test').addField('test2');
    info.mergeFields(['test2', 'jamon']);
    expect(info.containsField('test')).toEqual(false)
    expect(info.containsField('uhuh')).toEqual(false)
    expect(info.containsField('test2')).toEqual(true);
    expect(info.containsField('jamon')).toEqual(true);
  });
});
