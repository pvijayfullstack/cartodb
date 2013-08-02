/**
 *  entry point for table
 */


$(function() {

  var Table = cdb.core.View.extend({

    el: document.body,

    _TEXTS: {
      geocoding: {
        canceled: _t("Geocoding canceled")
      }
    },

    events: {
      'keypress': 'keyPress',
      'keyup': 'keyUp'
    },

    initialize: function(options) {
      var self = this;
      this.table = null;
      this.selectedMenu = null; // enable this
      this.workViewActive = 'table';
                                      // for oppening a menu in the startup
      // Get user layers as well
      this.options.user_data.get_layers = true;

      this.user = new cdb.admin.User(this.options.user_data);

      this._initModels();
      this._initViews();
      this._createLoader();

      cdb.admin.hotkeys.enable();
      this.keyBind();
    },

    /**
    * Bind the keystrokes associated with menu actions
    * alt + <- : show right menu
    * alt + -> : hide right menu
    * alt + c : toggle carto
    * alt + s : toggle sql
    * @method keyBind
    */
    keyBind: function() {
      var self = this;
      cdb.god.bind('hotkey:d', function(e) {
        self.menu.isOpen
          ? self.menu.hide()
          : self.menu.show('sql_mod');
      });
      cdb.god.bind('hotkey:s', function(e) {
        self.menu.show('sql_mod');
      })
      cdb.god.bind('hotkey:c', function(e) {
        self.menu.show('style_mod');
      })
    },

    _initModels: function() {
      var self = this;
      this.vis = new cdb.admin.Visualization(this.options.vis_data);
      this.vis.map.set(this.vis.map.parse(this.options.map_data));
      this.map = this.vis.map;

      var layers = cdb.admin.DEFAULT_LAYERS;
      this.baseLayers = this.user.layers;

      _(layers).map(function(m) {

        self.baseLayers.add(new cdb.admin.TileLayer({
          name:        m.name,
          className:   "default " + m.className,
          base_type:   m.className,
          urlTemplate: m.url,
          read_only:   true,
          maxZoom:     m.maxZoom,
          attribution: m.attribution
        }));

      });
    },

    _resetModel: function(_id) {
      this.vis = new cdb.admin.Visualization({ id: _id });
      this.vis.fetch();
    },

    _initViews: function() {
      var self = this;

      this.globalError = new cdb.admin.GlobalError({
        el: $('.globalerror')
      });
      this.globalError.listenGlobal();
      this.addView(this.globalError);

      // ***  tabs
      this.tabs = new cdb.admin.Tabs({
        el: this.$('nav'),
        slash: true
      });
      this.addView(this.tabs);

      // *** work pane (table and map)
      this.workView = new cdb.ui.common.TabPane({
        el: this.$('.panes')
      });

      this.addView(this.workView);

      // *** right menu
      this.menu = new cdb.admin.LayersPanel({
        vis: this.vis,
        user: this.user,
        globalError: this.globalError
      });

      this.$el.append(this.menu.render().el);
      this.menu.hide();
      this.addView(this.menu);

      this.menu.bind('switch', function(layerView) {
        this.setTable(layerView.table, layerView.sqlView);
        if(!this.tableTab) {
          this._initTableMap();
          this.table.trigger('change', this.table);
        }
        this.tableTab.setActiveLayer(layerView);
        this.mapTab.setActiveLayer(layerView);
        this.header.setActiveLayer(layerView);
      }, this);

      // global click
      enableClickOut(this.$el);

      // On resize window...
      $(window).bind("resize", this._onResize);
    },

    _initTableMap: function() {
      var self = this;
      
      // Init geocoder
      this.geocoder = new cdb.admin.Geocoding('', this.table);

      // New visualization header
      this.header = new cdb.admin.Header({
        el: this.$('header'),
        globalError: this.globalError,
        model: this.vis,
        user: this.user,
        config: this.options.config,
        geocoder: this.geocoder
      });
      this.addView(this.header);

      // Table tab
      this.tableTab = new cdb.admin.TableTab({
        model: this.table,
        vis: this.vis,
        sqlView: this.sqlView,
        geocoder: this.geocoder,
        globalError: this.globalError,
        menu: this.menu
      });

      // Map tab
      this.mapTab = new cdb.admin.MapTab({
        model: this.map,
        baseLayers: this.baseLayers,
        vis: this.vis,
        geocoder: this.geocoder,
        table: this.table,
        user_data: this.options.user_data,
        menu: this.menu
      });

      // Background geocoder
      var bkg_geocoder = this.bkg_geocoder = new cdb.admin.BackgroundGeocoder({
        template_base: 'table/views/geocoder_progress',
        import_: this.geocoder
      });
      this.$el.append(this.bkg_geocoder.render().el);
      bkg_geocoder.bindGeocoder();


      // Geocoding arguments
      // ev, msg, type (error, success)

      this.geocoder.bind('started', function(type, msg) {
        self.globalError.showError(msg, 'load', 0);
      });

      this.geocoder.bind('no-data', function(type, msg) {
        var georeference_alert = new cdb.admin.GeoreferenceNoDataDialog({model: this.model});
        self.$el.append(georeference_alert.render().el);
        georeference_alert.open();
      });

      bkg_geocoder.bind('canceled', function(type, msg) {
        // Refresh tiles
        if (self.mapTab.isMapEnabled()) self.mapTab.updateDataLayerView();
        self.globalError.showError(self._TEXTS.geocoding.canceled);
      });

      this.geocoder.bind('finished error offline templateError', function(type, msg) {
        if (( type == "error" || type == "finished") && self.mapTab.isMapEnabled()) self.mapTab.updateDataLayerView();
        if (type == "finished") {
          self.globalError.showError(msg);
        } else {
          self.globalError.showError(msg, "error", 10000);
        }
        
      }, this);
  
      this.map.bind('notice', this.globalError.showError, this.globalError);

      this.workView.bind('tabEnabled:map', this.mapTab.enableMap, this.mapTab);
      this.workView.bind('tabEnabled', this.tabs.activate);
      this.mapTab.bind('missingClick', self.menu.hide, self.menu);

      this.workView.addTab('table', this.tableTab.render(), { active: false });
      this.workView.addTab('map', this.mapTab.render(), { active: false });
      this.workView.active(this.workViewActive);
    },


    setTable: function(table, sqlView) {
      if(this.table) {
        this.table.unbind('notice', null, this.globalError);
      }
      this.table = table;
      this.sqlView = sqlView;
      this.table.bind('notice', this.globalError.showError, this.globalError);
    },


    // Close all dialogs in window resize
    _onResize: function(e) {
      cdb.god.trigger("closeDialogs");
    },

    keyUp: function(e) {},

    keyPress: function(e) {},

    // Big table loader
    _createLoader: function() {
      this.big_loader = new cdb.admin.TableBigLoader();
      this.$el.append(this.big_loader.render().el);
    },

    // Show big loader when changes to visualization
    // or table
    showLoader: function(type) {
      this.big_loader.change(type);
      this.big_loader.open();
    },

    // Hide big loader when visualization
    // or table finishes
    hideLoader: function() {
      this.big_loader.hide();
    },

    activeView: function(name) {
      this.workView.active(name);
      // table or map is active?
      this.menu.setActiveWorkView(name);
      this.workViewActive = name;
    }
  });

  cdb._test = cdb._test || {};
  cdb._test.Table = Table;


  cdb.init(function() {
    cdb.config.set(config);
    cdb.config.set('api_key', user_data.api_key);
    cdb.templates.namespace = 'cartodb/';

    var table = new Table({
      vis_data: vis_data,
      user_data: user_data,
      config: config,
      map_data: map_data
    });

    // Mixpanel test
    if (window.mixpanel) {
      new cdb.admin.Mixpanel({
        user: user_data,
        token: mixpanel_token
      });
    }
    
    // expose to debug
    window.table = table;
    window.table_router = new cdb.admin.TableRouter(table);

    Backbone.history.start({ pushState: true, root: "/" })
  });

});
