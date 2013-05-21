
/**
*  Tables list
*
*  It will show the user tables in a list
*
*  Usage example:
*
*  var tableList = new cdb.admin.dashboard.TableList({
*    el: this.$('#tablelist'),
*    collection: this.tables,
*    user: this.user   // it needs it to know if the user has limitations or not
*  });
*
*/

cdb.admin.dashboard.TableList = cdb.core.View.extend({

  tagName: 'ul',

  initialize: function() {
    this.collection.bind('add remove reset', this.render, this);
  },

  render: function() {
    this.clearSubViews();
    var self = this;

    this.collection.each(function(table) {
      var table_item = new cdb.admin.dashboard.TableItem({
        model: table,
        user: self.options.user
      })
      .bind('remove', function() {
        this.model.destroy();
      });

      self.$el.append(table_item.render().el);

      self.addView(table_item);
    });
  }

});

/**
* Single table item in dashboard tables list
*
* Usage example:
*
*  var li = new cdb.admin.dashboard.TableItem({
*    model: table_model,
*    limitation: !this.options.user.get("private_tables")
*  });
*
*/

cdb.admin.dashboard.TableItem = cdb.core.View.extend({

  tagName: 'li',

  _TAGS_PER_ITEM: 20,

  _PRIVACY_VALUES: ['public','private'],

  events: {
    'click a.delete': '_deleteTable',
    'click a.status': '_changePrivacy'
  },

  initialize: function() {
  _.bindAll(this, "_changePrivacy");

    this.template = cdb.templates.getTemplate('dashboard/views/table_list_item');

    this.model.bind('change:privacy',     this._setPrivacy,     this);
  },

  _generateTagList: function(tags) {

    if (!tags) return;

    var template = _.template('<a href="/dashboard/table/tag/<%= tag %>" data-tag="<%= tag %>"><%= tag %></a>');

    return _.map(tags, function(t) {
      return template({ tag: t });
    }).reverse().slice(0, this._TAGS_PER_ITEM).join(" ");

  },

  _cleanString: function(s, n) {

    if (s) {
      s = s.replace(/<(?:.|\n)*?>/gm, ''); // strip HTML tags
      s = s.substr(0, n-1) + (s.length > n ? '&hellip;' : ''); // truncate string
    }

    return s;

  },

  render: function() {
    var attrs = this.model.toJSON();

    attrs.table_size = this._bytesToSize(attrs.table.size);

    var tags = this._generateTagList(attrs.tags);

    var description = this._cleanString(this.model.get("description"), 55);

    this.$el.append(this.template(_.extend(attrs, { description: description, tags: tags })));

    this.$('a.delete').tipsy({ gravity: 's', fade: true });

    return this;
  },

  _deleteTable: function(e) {
    this.killEvent(e);
    this._confirmAndDelete(e);
  },

  /**
  * Show delete confirmation after decides delete a table
  */
  _confirmAndDelete: function(ev) {
    var self = this;
    ev && (ev.preventDefault());

    this.delete_dialog = new cdb.admin.DeleteDialog({
      model: this.model,
      title: "Delete this table",
      ok_title: "Delete this table",
      content: 'You are about to delete this table. Doing so will result in the deletion of this dataset. We recommend you export it before deleting it.',
      config: this.options.config
    });

    $("body").append(this.delete_dialog.render().el);
    this.delete_dialog.open();

    this.delete_dialog.wait()
    .done(this.deleteTable.bind(this))
    .fail(this.cleanDeleteDialog.bind(this));
  },

  cleanDeleteDialog: function() {
    this.delete_dialog.clean();
  },

  deleteTable: function() {
    this.trigger('remove');
  },

  clean: function() {
    // Remove tipsy
    if (this.$("a.delete").data('tipsy')) {
      this.$("a.delete").unbind('mouseenter mouseleave');
      this.$("a.delete").data('tipsy').remove();
    }

    cdb.core.View.prototype.clean.call(this);
  },

  /**
   *  Set privacy status
   */
  _setPrivacy: function() {
    var $status = this.$('a.status');

    for(var n in this._PRIVACY_VALUES) {
      var privacyName = this._PRIVACY_VALUES[n]
      $status.removeClass(privacyName);
    }

    $status
      .addClass(this.model.get('privacy').toLowerCase())
      .html(this.model.get('privacy'))
      .show();
  },

  /**
   *  Update the privacy status
   */
  _changePrivacy: function(ev) {
    ev.preventDefault();

    this.privacy && this.privacy.clean();
    cdb.god.trigger("closeDialogs");

    // Add privacy selector
    var privacy = this.privacy = new cdb.admin.PrivacySelector({
      model: this.model,
      limitation: !this.options.user.get("actions").private_tables,
      direction: 'up',
      upgrade_url: window.location.protocol + '//' + config.account_host + "/account/" + user_data.username + "/upgrade"
    });

    cdb.god.bind("closeDialogs", this.privacy.hide, this.privacy);

    // Set position and show privacy selector
    this.$el.find(".table_info").append(this.privacy.render().el);
    this.privacy.show($(ev.target), "position");

    return false;
  },


  // Help functions
  _bytesToSize: function(by) {
    var bytes = parseInt(by.toString())
    , sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    if (bytes == 0) return '0 KB';
    var i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
    var value = (bytes / Math.pow(1024, i)).toFixed(2);

    if (value % 1 == 0) {
      value = parseInt(value)
    }

    return value + " " + sizes[i];
  }
});
