  
  /** 
   *  Public map "view"
   *
   */


  cdb.open.MapPublic = cdb.core.View.extend({

    el: document.body,

    events: {
      'click .export_options .clone':   '_copyVisToYourAccount',
      'click .export_options .js-like': '_onClickLike',
      'click':                          '_onClick'
    },

    _TEXTS: {
      copy_vis_dialog: {
        title:  _t('Name for your copy of this visualization'),
      }
    },

    initialize: function() {
      this.authenticated_user = new cdb.open.AuthenticatedUser();

      this.vis = new cdb.open.PublicVisualization({
        id:   this.options.vis_id,
        name: this.options.vis_name,
        likes: this.options.vizdata.likes
      });

      this._initViews();
      this._initBinds();

      this.authenticated_user.fetch();
    },

    _initBinds: function() {
      this.authenticated_user.bind('change', this._onUserLogged, this);
      this.add_related_model(this.authenticated_user);
      this.vis.like.bind("change:likes, change:liked", this._onLikeChange, this);
    },

    _initViews: function(e) {
      // Public header
      if (this.$('.cartodb-public-header').length > 0) {
        var header = new cdb.open.Header({
          el: this.$('.cartodb-public-header'),
          model: this.authenticated_user,
          current_view: this._getCurrentView(),
          owner_username: this.options.owner_username,
          vis: this.vis,
          isMobileDevice: this.options.isMobileDevice
        });
        this.addView(header);
      }

      // Tipsy for help
      this.$("span.help").tipsy({ gravity: $.fn.tipsy.autoBounds(250, 's'), fade: true });

      // Check if comments are available for user browser
      if ($.browser.msie && parseInt($.browser.version) == 7 ) {
        this.$(".comments .content").html("<p>Your browser doesn't support comments.</p>")
      }

      // Public vis
      this.map_vis = new cdb.open.PublicVis(_.defaults({ el: this.$('#map') }, this.options));
      this.map_vis.bind('map_error', this._showNotSupportedDialog, this);
      this.map_vis.bind('map_loaded', function(vis) { this.trigger('map_loaded', vis, this) }, this);
      this.addView(this.map_vis);
    },

    _onClick: function() {
      cdb.god.trigger("closeDialogs");
    },

    _onClickLike: function(e) {
      this.killEvent(e);
      this.vis.like.toggleLiked();
    },

    // Get type of current view
    // - It could be, dashboard, table or visualization
    _getCurrentView: function() {
      var pathname = location.pathname;

      if (pathname.indexOf('/tables/') !== -1 ) {
        return 'table';
      }

      if (pathname.indexOf('/viz/') !== -1 ) {
        return 'visualization';
      }

      // Other case -> dashboard (datasets, visualizations,...)
      return 'dashboard';

    },

    _onLikeChange: function() {

      this.$el.find(".js-like .counter").text(this.vis.like.get("likes"));

      var $button  = this.$el.find(".js-like");
      var $icon    = this.$el.find(".js-like .icon");
      var $counter = this.$el.find(".js-like .counter");

      if (this.vis.like.get("liked")) {

        $button.addClass("is-highlighted");
        $icon.addClass("is-pulsating is-animated");
        $icon.one('webkitAnimationEnd mozAnimationEnd MSAnimationEnd oanimationend animationend', function() {
          $(this).removeClass("is-pulsating is-animated");
        });

      } else {

        $icon.addClass("is-pulsating is-animated");
        $icon.one('webkitAnimationEnd mozAnimationEnd MSAnimationEnd oanimationend animationend', function() {
          $(this).removeClass("is-pulsating is-animated");
          $button.removeClass("is-highlighted");
        });

      }

    },

    _onUserLogged: function() {
      var visible_clone = false;
      var visible_edit  = false;
      var visible_like  = false;

      // Check if clone button should be visible
      if (!this.options.isMobileDevice && this.authenticated_user.get('can_fork') && this.options.owner_username !== this.authenticated_user.get('username')) {
        this.$('.export_options .clone').css('display', 'inline-block');
        visible_clone = true;
      }

      // Check if edit & likes button should be visible
      if (this.options.owner_username === this.authenticated_user.get('username')) {
        this.$('.export_options .edit').css('display', 'inline-block');
        visible_edit = true;
      }

      if (this.authenticated_user.get('username')) {
        this.$('.export_options .js-like').css('display', 'inline-block');
        this.vis.like.set({ username: this.authenticated_user.get("username") });
        this.vis.like.fetch();
        this.$('.export_options .js-like').show();
        visible_like = true;
      }

      if (!visible_clone && !visible_edit && !visible_like) {
        this.$('.export_options').hide();
      }
    },

    _showNotSupportedDialog: function() {
      this.$('#not_supported_dialog').show();
    },

    _copyVisToYourAccount: function(e) {
      this.killEvent(e);

      var dlg = new cdb.admin.DuplicateVisDialog({
        model: this.vis,
        title: this._TEXTS.copy_vis_dialog.title
      });

      dlg
        .appendToBody()
        .open();
    },

    // public methods
    
    invalidateMap: function() {
      this.map_vis && this.map_vis.invalidateMap();
    }

  });
