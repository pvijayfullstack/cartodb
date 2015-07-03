var cdb = require('cartodb.js');
var Utils = require('cdb.Utils');
var BaseDialog = require('../../views/base_dialog/view');
var ViewFactory = require('../../view_factory');
var randomQuote = require('../../view_helpers/random_quote');

module.exports = BaseDialog.extend({

  _CARD_WIDTH: 288,
  _CARD_HEIGHT: 170,
  _TABS_PER_ROW: 3,
  _EXCLUDED_COLUMNS: ['cartodb_id', 'the_geom', 'lat', 'lon', 'lng', 'long', 'latitude', 'longitude', 'shape_length', 'shape_area', 'objectid', 'id', 'country', 'state', 'created_at', 'updated_at', 'iso2', 'iso3', 'x_coord', 'y_coord', 'xcoord', 'ycoord'],

  events: cdb.core.View.extendEvents({
    "click .js-goPrev": "_prevPage",
    "click .js-goNext": "_nextPage",
    "click .js-skip"  : "_onSkipClick"
  }),

  initialize: function() {
    this.elder('initialize');

    if (!this.options.table) {
      throw new Error('table is required');
    }

    this._initModels();
    this._initViews();
    this._initBinds();
  },

  render_content: function() {
    return this._panes.getActivePane().render().el;
  },

  render: function() {
    BaseDialog.prototype.render.apply(this, arguments);
    return this;
  },

  _initModels: function() {
    this.columns = new Backbone.Collection();
    this.model = new cdb.core.Model({ page: 1, maxPages: 0 });
  },

  _initViews: function() {

    _.bindAll(this, "_onDescribeSuccess", "_addCard", "_generateThumbnail", "_analyzeColumn", "_analyzeColumns", "_refreshMapList", "_onLoadWizard", "_analyzeStats");

    this.table = this.options.table;

    this._panes = new cdb.ui.common.TabPane({
      el: this.el
    });

    this.addView(this._panes);

    this._panes.addTab('vis',
      ViewFactory.createByTemplate('common/dialogs/pecan/template', {
      })
    );

    this._panes.addTab('loading',
      ViewFactory.createByTemplate('common/templates/loading', {
        title: 'Analyzing your data…',
        quote: randomQuote()
      })
    );

    this._panes.addTab('fail',
      ViewFactory.createByTemplate('common/templates/fail', {
        msg: 'Could not delete row for some reason'
      })
    );

    this._panes.active('loading');
    this._start();
  },

  _onSkipClick: function(e) {
    this.killEvent(e);
    this.close();
    this.trigger("skip", this);
  },

  _nextPage: function() {
    var page = this.model.get('page');
    var maxPages = this.model.get('maxPages');

    if (page < maxPages) {
      this.model.set('page', page + 1);
    }
  },

  _prevPage: function() {
    var page = this.model.get('page');
    if (page > 1) {
      this.model.set('page', page - 1);
    }
  },

  _moveTabsNavigation: function() {
    var page = this.model.get('page');
    var rowWidth = 990;

    var p = rowWidth * (page - 1);
    this.$('.js-map-list').css('margin-left', '-' + p + 'px');
    this._refreshNavigation();
  },

  _refreshNavigation: function() {
    var page = this.model.get('page');
    var maxPages = this.model.get('maxPages');

    this.$('.js-goPrev')[ page > 1 ? 'removeClass' : 'addClass' ]('is-disabled');
    this.$('.js-goNext')[ page < maxPages ? 'removeClass' : 'addClass' ]('is-disabled');
  },

  _hideNavigation: function() {
    this.$('.js-navigation').addClass("is-hidden");
  },

  _initBinds: function() {
    this.model.bind('change:page', this._moveTabsNavigation, this);
    this.columns.bind('change', this._onChangeColumns, this);
    this._panes.bind('tabEnabled', this.render, this);
  },

  _onChangeColumns: function(column) {

    console.log("%c" + column.get("name") + ": " + this._getAnalyzedColumns().length + "/" + this.columns.length, "font-weight: bold;");

    if (this._getAnalyzedColumns().length === this.columns.length) {
      if (this._getSuccessColumns().length === 0) {
        this.close();
      } else  if (this.columns.length < 4) {
        this._hideNavigation();
      }
    }
  },

  _generateThumbnail: function(column, callback) {

    var template = this.options.map.getLayerAt(0).get("urlTemplate");

    var layer_definition = {
      user_name: user_data.username,
      maps_api_template: cdb.config.get('maps_api_template'),
      layers: [{
        type: "http",
        options: {
          urlTemplate: template,
          subdomains: [ "a", "b", "c" ]
        }
      }, {
        type: "cartodb",
        options: {
          sql: column.get("sql"),
          cartocss: column.get("css"),
          cartocss_version: "2.1.1"
        }
      }]
    };

    if (column.get("wizard") === "torque"){
      layer_definition.layers[1] = {
        type: "torque",
        options: {
          sql: column.get("sql"),
          cartocss: column.get("css"),
          cartocss_version: "2.1.1"
        }
      }
    }

    var zoom   = this.options.map.get("zoom");
    var center = this.options.map.get("center");

    cdb.Image(layer_definition).size(this._CARD_WIDTH, this._CARD_HEIGHT).zoom(zoom).center(center).getUrl(function(error, url) {
      callback && callback(error, url);
    });

  },

  _analyzeStats: function(name, stats) {

    console.log("analyzing " + name);

    if (!stats.count) {
      console.log("%c"+name + ' rejected because zero count: ' + stats.count, "font-weight: bold; color:red;");
      return false;
    }

    if (stats.count > 7000) {
      console.log("%c"+name + ' rejected because more than 7000 rows: ' + stats.count, "font-weight: bold; color:red;");
      return false;
    }

    if (stats.null_ratio > 0.75) {
      console.log("%c"+name + ' rejected because the null ratio > 75%: ' + stats.null_ratio * 100, "font-weight: bold; color:red;");
      return false;
    }

    var distinctPercentage = (stats.distinct / stats.count) * 100;

    if (distinctPercentage > 75) {
      console.log("%c"+name + ' rejected because the distinctPercentage > 75: ' + distinctPercentage, "font-weight: bold; color:red;");
      return false;
    }

    return true;

  },

  _analyzeColumn: function(column) {

    var self = this;

    if (_.include(this._EXCLUDED_COLUMNS, column.get("name"))) {
      column.set({ analyzed: true, success: false });
      return;
    }

    this.sql.describe(this.query, column.get("name"), function(stats) {
      console.log('describing ', name);

      if (!stats) {
        console.log('describe returned no stats for ' + colum.get("name"));
        column.set({ analyzed: true, success: false });
        return;
      }

      if (!self._analyzeStats(column.get("name"), stats)) {
        column.set({ analyzed: true, success: false });
        return;
      }

      var response = cdb.CartoCSS.guessMap(self.query, self.options.table.get("name"), column, stats);

      if (response) {

        column.set({ analyzed: true, success: true, sql: response.sql, css: response.css, wizard: response.wizard });

        self._generateThumbnail(column, function(error, url) {
          if (!error) {
            self._addCard(url, response);
          } else {
            column.set({ analyzed: true, success: false });
            console.log(column.get("name"), error); // TODO: remove this
          }
        });
      } else {
        column.set({ analyzed: true, success: false });
      }
    });
  },

  _addCard: function(url, response) {
    var self = this;

    var src = url + "?api_key=" + this.options.user.get("api_key");

    var wizardName = response.wizard.charAt(0).toUpperCase() + response.wizard.slice(1);

    var $el = $(cdb.templates.getTemplate('common/dialogs/pecan/card')({
      column: response.column,
      wizard: wizardName,
      null_count: Utils.formatNumber(response.null_count),
      weight: response.stats.weight,
    }));

    var img = new Image();

    img.onerror = function() {
      console.log("error loading the image for " + response.column);
    };

    img.onload  = function() {
      $el.find(".js-loader").hide();
      $el.find(".js-header").append('<img class="MapCard-preview" src="' + src + '" />')
      $el.find("img").show();
    };

    img.src = src;

    this.$(".js-map-list").append($el);
    this._panes.active('vis');

    $el.on("click", function(e) {
      self.killEvent(e);
      self.model.set("response", response);
      self._onCardClick();
    });

    this._refreshMapList($el);
    this._refreshNavigation();
  },

  _refreshMapList: function($el) {
    var w = $el.width();
    var l = this.$(".js-card").length;
    this.$(".js-map-list").width(w * l + (l - 1) * 30);
    this.model.set('maxPages', Math.ceil(this.$('.js-card').size() / this._TABS_PER_ROW));
  },

  _getPending: function() {
    return this.columns.filter(function(c) { return !c.get("analyzed")})
  },

  _getAnalyzedColumns: function() {
    return this.columns.filter(function(c) { return c.get("analyzed")})
  },

  _getSuccessColumns: function() {
    return this.columns.filter(function(c) { return c.get("success")})
  },

  _start: function() {
    this.query = 'SELECT * FROM ' + this.table.id;
    this.sql = cdb.admin.SQL();
    this.sql.describe(this.query, 'the_geom', this._onDescribeSuccess);
  },

  _onDescribeSuccess: function(data) {

    if (!data) {
      this.close();
      return;
    }

    var self = this;

    var geometryType = data.simplified_geometry_type;

    this.sql.columns(this.query, function(columns) {

      console.log("Analyzing " + _(columns).size());

      _(columns).each(function(type, name) {
        this.columns.add({ name: name.concat(""), type: type, geometry_type: geometryType, bbox: data.bbox, analyzed: false })
      }, self);

      self._analyzeColumns();

    });

  },

  _geoAttr: function(geometryType) {
    return {
      "line": 'line-color: #A6CEE3',
      'polygon': "polygon-fill: #A6CEE3",
      'point': "marker-fill: #A6CEE3"
    }[geometryType];
  },

  _onCardClick: function() {
    var self = this;
    var dataLayers = this.options.map.layers.getDataLayers();
    this.layer = dataLayers[0];

    var wizard = this.model.get("response").wizard;
    var properties = {};

    if (wizard === "category") {
      var geometryType = this.model.get("response").geometryType;
      properties   = this._geoAttr(geometryType);
    }

    if (this.layer) {
      this.layer.wizard_properties.unbind("load", this._onLoadWizard, this);
      this.layer.wizard_properties.bind("load", this._onLoadWizard, this);

      var properties = this.layer.wizard_properties.propertiesFromStyle(this.model.get("response").css);
      this.layer.wizard_properties.active(wizard, properties); 
      this.layer.wizard_properties.set({ property: this.model.get("response").column });
    }

    this.close();
    //this.trigger("skip", this); // TODO: enable this after the manual testing is finished
  },

  _onLoadWizard: function() {

    var response = this.model.get("response");

    var property = response.column;
    var wizard = response.wizard;

    if (wizard === 'choropleth') {
      var dist = response.stats.dist_type;
      var ramp = "inverted_red";

      if (dist === 'A' || dist === 'U') {
        ramp = "spectrum2";
      }
      else if (dist === 'F') {
        ramp = "red";
      }
      else if (dist === 'J') {
        ramp = "green";
      }

      console.log("%capplying: " + ramp +  " to " + property + " (" + dist + ")", 'background: #f1f1f1; ' );

      this.layer.wizard_properties.set({ color_ramp: ramp, property: property });
    } else {
      this.layer.wizard_properties.set({ property: property });
    }

  },

  _analyzeColumns: function() {
    this.columns.each(this._analyzeColumn);
  },

  _keydown: function(e) {
    if (e.keyCode === $.ui.keyCode.LEFT) {
      this._prevPage();
    } else if (e.keyCode === $.ui.keyCode.RIGHT) {
      this._nextPage();
    }
    cdb.admin.BaseDialog.prototype._keydown.call(this, e);
  },

  clean: function() {
    if (this.layer) {
      this.layer.wizard_properties.unbind("load", this._onLoadWizard, this);
    }

    cdb.admin.BaseDialog.prototype.clean.call(this);
  }
});
