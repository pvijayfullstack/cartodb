/**
 *  Entry point for dashboard
 */


$(function() {

  var Dashboard = cdb.core.View.extend({

    el: document.body,

    events: {},

    initialize: function() {
      this._initModels();
      this._initViews();
    },

    _initModels: function() {
      this.user = new cdb.admin.User(this.options.user_data);
      this.tables = new cdb.admin.Tables();
      this.tags = new cdb.admin.Tags();
      this.first_time = true;

      // The user model has to update every time the table model
      this.tables.bind('add remove reset', function(){
        if (!this.first_time)
          this.user.fetch();

        this.first_time = false;
      }, this);
      this.tables.bind('error', function(e) {
        cdb.log.info("error", e);
      });
    },

    _initViews: function() {
      // Table list
      this.tableList = new cdb.admin.dashboard.TableList({
        el: this.$('#tablelist'),
        model: this.tables,
        config: this.options.config,
        user: this.user
      });

      // User data
      this.tableStats = new cdb.admin.dashboard.TableStats({
        el: this.$('div.subheader'),
        model: this.user
      });

      this.tableStats.render();

      // Choose sceneario
      this.scenario = new cdb.admin.dashboard.Scenario({
        el: this.$el,
        model: this.user
      });

      // Search form
      var search_form = this.search_form = new cdb.ui.common.SearchView({
        el: this.$('header ul li.search')
      });

      // User menu
      var user_menu = this.user_menu = new cdb.admin.DropdownMenu({
        target: $('a.account'),
        host: config.account_host,
        username: username,
        template_base: 'common/views/settings_item'
      });
      cdb.god.bind("closeDialogs", user_menu.hide, user_menu);
      this.$el.append(this.user_menu.render().el);

      // Background Importer
      var bkg_importer = this.bkg_importer = new cdb.ui.common.BackgroundImporter({
        template_base: 'common/views/background_importer'
      });
      this.$el.append(this.bkg_importer.render().el);

      // Paginator
      var paginator = this.paginator = new cdb.admin.dashboard.DashboardPaginator({
        el: this.$("div.paginator"),
        model: this.tables
      });

      // Tables tags
      var tagsView = this.tagsView = new cdb.admin.dashboard.TagsView({
        el: this.$('aside div.content ul:eq(0)'),
        tables: this.tables,
        model: this.tags
      });

      // Tipsy
      this.$el.find("a.tooltip").tipsy({gravity: 's', fade:true, live:true});

      // Create new table view
      var createTable = this.createTable = new cdb.admin.dashboard.CreateTable({
        el: this.$el,
        importer: bkg_importer,
        tables: this.tables,
        model: this.user
      });

      // global click
      enableClickOut(this.$el);
    },


    /**
     *  If application suffers any update in the Router
     *  moves the window at the top to see the loader
     */
    scrollTop: function() {
      this.$el.animate({
        scrollTop: 0
      },500);
    }

  });

  var DashboardRouter = Backbone.Router.extend({

    routes: {
      '':                 'index',
      'page/:p':          'paginate',
      'tag/:tag/:p':      'searchTag',
      'search/:query/:p': 'searchQuery'
    },

    initialize: function() {
      window.dashboard.tables.options.bind("change", this.update ,this);
    },

    update: function() {
      window.dashboard.scrollTop();
      var hash = window.location.hash.split("/");
      hash[hash.length - 1] = window.dashboard.tables.options.get("page");
      this.navigate(hash.join("/"));
    },

    index: function() {
      window.dashboard.tables.options.set({
        "tag_name"  : "",
        "q"         : "",
        "page"      : 1
      });
    },
    searchTag: function(tag,p) {
      window.dashboard.tables.options.set({
        "tag_name"  : tag,
        "page"      : p,
        "q"         : ""
      });
    },
    searchQuery: function(query,p) {
      window.dashboard.tables.options.set({
        "tag_name"  : "",
        "page"      : p,
        "q"         : query
      });
    },
    paginate: function(p) {
      window.dashboard.tables.options.set({
        "tag_name"  : "",
        "page"      : p,
        "q"         : ""
      });
    }
  });

  cdb.init(function() {
    cdb.templates.namespace = 'cartodb/';
    var dashboard = new Dashboard({
      user_data: user_data,
      config: config
    });

    // Expose to debug
    window.dashboard = dashboard;

    // Routing
    var router = new DashboardRouter();
    Backbone.history.start();

    // No route => tables fetch
    if (window.dashboard.tables.options.get("tag_name") === "" && 
      window.dashboard.tables.options.get("q") === "") {
      window.dashboard.tables.fetch();
    }
  });

});
