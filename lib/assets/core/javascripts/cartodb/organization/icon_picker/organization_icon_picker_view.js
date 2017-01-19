var cdb = require('cartodb.js-v3');
var IconPickerView = require('./icons/organization_icons_view');
var IconCollection = require('./icons/organization_icon_collection');
var IconView = require('./icons/organization_icon_view');
var IconPickerDialog = require('./icon_picker_dialog/icon_picker_dialog_view');

module.exports = IconPickerView.extend({

  events: IconPickerView.extendEvents({
    'click .js-viewAllIcons': '_onViewAllIconsClicked'
  }),

  initialize: function () {
    if (!this.options.user) { throw new Error('user is required.'); }
    this._user = this.options.user;

    this._maxIcons = 1;
    this.template = cdb.templates.getTemplate('organization/icon_picker/organization_icon_picker_template');
    this.model = new cdb.core.Model({
      isProcessRunning: false
    });
    this._iconCollection = new IconCollection(null, {
      orgId: this._user.organization.get('id')
    });
    this._numOfUploadingProcesses = 0;
    this._numOfDeletingProcesses = 0;
    this._fetchErrorMessage = 'Error fetching your icons. Please refresh the page.';
    this._runningMessage = '';
    this.render();
    this._fetchAllIcons();
    this._initBinds();
  },

  _initBinds: function () {
    var self = this;

    this._iconCollection.on('change:selected', this._refreshActions, this);
    this.model.on('change:isProcessRunning', this._onProcessRunningChanged, this);

    cdb.god.bind('refreshCollection', function () {
      self.render();
      self._fetchAllIcons();
    });
  },

  _renderIcon: function (iconModel) {
    if (iconModel.get('index') < this._maxIcons) {
      var iconView = new IconView({
        model: iconModel
      });
      iconView.render();
      iconModel.set('visible', true);
      this.$('.js-items').append(iconView.$el);
    }
  },

  _addIconElement: function (iconModel) {
    iconModel.set('index', this._getIconIndex(iconModel));
    this._renderIcon(iconModel);
    this._refreshActions();
  },

  _refreshActions: function () {
    if (this.model.get('isProcessRunning')) {
      return;
    }
    var limit = Math.min(this._maxIcons, this._iconCollection.length);
    var numOfSelectedIcons = this._getNumberOfSelectedIcons();
    var iconText = (numOfSelectedIcons === 1 ? '1 icon selected' : '' + numOfSelectedIcons + ' icons selected');
    this.$('.js-iconMainLabel').text(iconText);

    if (numOfSelectedIcons === 0) {
      this.$('.js-iconMainLabel').text('Icons');
      this._hide('.js-selectAllIcons, .js-deselectAllIcons, .js-deleteIcons');
      this._show('.js-iconsInfo');
    } else if (numOfSelectedIcons < limit) {
      this._show('.js-selectAllIcons, .js-deleteIcons');
      this._hide('.js-deselectAllIcons, .js-iconsInfo');
    } else {
      this._hide('.js-selectAllIcons, .js-iconsInfo');
      this._show('.js-deselectAllIcons, .js-deleteIcons');
    }

    if (this._iconCollection.length > this._maxIcons) {
      this._show('.js-viewAllIcons');
    } else {
      this._hide('.js-viewAllIcons');
    }
  },

  _hideActions: function () {
    this._hide('.js-selectAllIcons, .js-deselectAllIcons, .js-deleteIcons, .js-iconsInfo, .js-viewAllIcons');
  },

  _getIconIndex: function (icon) {
    return this._iconCollection.indexOf(icon);
  },

  _addExtraIcon: function () {
    var iconAdded = false;
    this._iconCollection.each(function (icon) {
      var index = this._getIconIndex(icon);
      if (index < this._maxIcons && !icon.get('visible') && !iconAdded) {
        this._addIconElement(icon);
        iconAdded = true;
      }
    }, this);
  },

  _bindIconsPicker: function () {
    cdb.god.bind('closeDialogs:icons', this._destroyPicker, this);
  },

  _unbindIconsPicker: function () {
    cdb.god.unbind('closeDialogs:icons', this._destroyPicker, this);
  },

  _destroyPicker: function () {
    if (this.icon_picker_dialog) {
      this._unbindIconsPicker();
      this.icon_picker_dialog.remove();
      this.removeView(this.icon_picker_dialog);
      this.icon_picker_dialog.hide();
      delete this.icon_picker_dialog;
    }
  },

  _onViewAllIconsClicked: function (e) {
    this.killEvent(e);

    cdb.god.trigger('closeDialogs:icons');

    this.icon_picker_dialog = new IconPickerDialog({
      user: this._user,
      kind: 'organization_asset'
    });
    this.icon_picker_dialog.appendToBody();

    this._bindIconsPicker();
    this.addView(this.icon_picker_dialog);
  }
});
