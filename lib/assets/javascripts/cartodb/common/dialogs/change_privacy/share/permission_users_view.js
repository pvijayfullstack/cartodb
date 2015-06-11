var cdb = require('cartodb.js');
var _ = require('underscore');
var $ = require('jquery');
var PermissionView = require('./permission_view');
var PaginationView = require('../../../views/pagination/view');

/**
 * Content view of the share dialog, lists of users to share item with.
 */
module.exports = cdb.core.View.extend({

  initialize: function() {
    this.paginationModel = this.options.paginationModel;
    this._initBinds();
  },

  render: function() {
    this.clearSubViews();

    this.$el.empty();

    if (!this.collection.getSearch()) {
      this._renderOrganizationPermissionView()  
    }
    this._renderUsersPermissionView();
    this._renderPaginationView();
    return this;
  },

  _initBinds: function() {
    this.collection.bind('reset', this.render, this);
    this.add_related_model(this.collection);
  },

  _renderUsersPermissionView: function() {
    var usersUsingVis = this.model.usersUsingVis();
    this.collection.each(function(user) {
      this._appendPermissionView(
        new PermissionView({
          model: user,
          permission: this.model.get('permission'),
          canChangeWriteAccess: this.model.canChangeWriteAccess(),
          title: user.get('username'),
          desc: user.get('name'),
          email: user.get('email'),
          avatarUrl: user.get('avatar_url'),
          isUsingVis: _.any(usersUsingVis, function(u) { return u.id === user.get('id'); })
        })
      )
    }, this);
  },

  _renderOrganizationPermissionView: function() {
    this._appendPermissionView(
      new PermissionView({
        model: this.model.get('organization'),
        permission: this.model.get('permission'),
        canChangeWriteAccess: this.model.canChangeWriteAccess(),
        title: 'Default settings for your Organization',
        desc: 'New users will have this permission'
      })
    );
  },

  _renderPaginationView: function() {
    var $paginatorWrapper = $('<div>').addClass('ChangePrivacy-shareListPagination');
    this.$el.append($paginatorWrapper);
    var paginationView = new PaginationView({
      model: this.paginationModel
    });
    $paginatorWrapper.append(paginationView.render().el);
    this.addView(paginationView);
  },

  _appendPermissionView: function(view) {
    this.$el.append(view.render().el);
    this.addView(view);
  }

});
