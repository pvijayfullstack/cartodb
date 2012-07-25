
/**
 * small photo of available base map layers
 */
cdb.admin.BaseMapView = cdb.core.View.extend({

  events: {
    'click': 'activate'
  },

  defaults: {
    x: 2005,
    y: 1544,
    z: 12
  },

  tagName: 'li',

  initialize: function() {
    this.options = _.defaults(this.options,this.defaults);
    this.map = this.options.map;
  },

  render: function() {
    //TODO: move this to model
    var back_tile = this.model.get("urlTemplate").replace("{z}", this.options.z).replace("{x}", this.options.x).replace("{y}", this.options.y)
      , a = this.make("a", {"style": "background:url(" + back_tile + ") no-repeat 0 0"}, this.cid);

    this.$el.html(a);

    return this;
  },

  activate: function(e) {
    e.preventDefault();
    var layer = this.map.getBaseLayer();
    layer.set(this.model.toJSON());
    cdb.log.debug("enabling layer: " + layer.get('urlTemplate'));
    return false;
  }

});

cdb.admin.BaseMapChooser = cdb.core.View.extend({

  tagName: 'ul',

  initialize: function() {
    _.bindAll(this, 'add');
    this.baseLayers = this.options.baseLayers;
    this.baseLayers.bind('reset', this.render, this);
    this.baseLayers.bind('add', this.add, this);
  },

  _addAll: function() {
    this.baseLayers.each(this.add);
  },

  add: function(lyr) {
    var v = new cdb.admin.BaseMapView({ model: lyr, map: this.model });
    cdb.log.debug("added base layer option: " + lyr.get('urlTemplate'));
    this.addView(v);
    this.$el.append(v.render().el);
  },

  render: function() {
    this.$el.html('');
    this._addAll();
    return this;
  }

});

cdb.admin.MapTab = cdb.core.View.extend({

  className: 'map',

  initialize: function() {
    this.map = this.model;
    this.map_enabled = false;
    this.infowindowModel = this.options.infowindow;

    this.add_related_model(this.options.dataLayer);
    this.add_related_model(this.map);
    this.add_related_model(this.options.table);
    this.add_related_model(this.infowindowModel);
  },

  enableMap: function() {
    var self = this;
    if(!this.map_enabled) {
        var div = $('<div>').attr("id","map")
          , base_maps = $('<div>').attr("class","base_maps");
        // div.css({'height': '900px'});
        this.baseLayerChooser = new cdb.admin.BaseMapChooser({
          model: this.map,
          baseLayers: this.options.baseLayers
        });
        
        base_maps.append(this.baseLayerChooser.render().el);

        this.$el.append(div);
        this.$el.append(base_maps);
        this.mapView = new cdb.geo.LeafletMapView({
          el: div,
          map: this.map
        });
        this.map_enabled = true;

        this.map.layers.bind('add', function(lyr) {
          if(lyr.cid == self.options.dataLayer.cid) {
            self.layerDataView = self.mapView.getLayerByCid(self.options.dataLayer.cid);

            self.layerDataView.bind('featureClick', self.featureClick, self);
            self.infowindow = new cdb.admin.MapInfowindow({
              model: self.infowindowModel,
              template: cdb.templates.getTemplate('table/views/infowindow'),
              mapView: self.mapView,
              table: self.options.table
            });
            self.mapView.$el.append(self.infowindow.el);
          }
        });

    }
  },

  featureClick: function(e, latlon, pxPos, data) {
    if(data.cartodb_id) {
      this.infowindow
        .setLatLng(latlon)
        .setFeatureInfo(data.cartodb_id)
        .showInfowindow();
    } else {
      cdb.log.error("can't show infowindow, no cartodb_id on data");
    }
  },

  render: function() {
    // this.$el.css({'height': '900px'});
    return this;
  }

});

