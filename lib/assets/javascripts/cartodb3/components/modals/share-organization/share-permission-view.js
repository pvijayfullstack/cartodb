var _ = require('underscore');
var CoreView = require('backbone/core-view');
var template = require('./share-permission.tpl');
var TipsyTooltipView = require('../../tipsy-tooltip-view.js');
var $ = require('jquery');

var REQUIRED_OPTS = [
  'model',
  'permission',
  'name',
  'canChangeReadAccess',
  'hasReadAccess',
  'hasWriteAccessAvailable',
  'canChangeWriteAccess',
  'hasWriteAccess'
];

var OPTIONALS_OPT = [
  'description',
  'role',
  'avatar'
];

module.exports = CoreView.extend({
  className: 'Share-permission',

  events: {
    'change .js-read': '_onChangeRead',
    'change .js-write': '_onChangeWrite',
    'mouseover .js-toggler.is-disabled': '_onHoverDisabledToggler',
    'mouseout .js-toggler': '_destroyTooltip',
    'mouseleave .js-toggler': '_destroyTooltip'
  },

  initialize: function (opts) {
    _.each(REQUIRED_OPTS, function (item) {
      if (opts[item] === undefined) throw new Error(item + ' is required');
      this['_' + item] = opts[item];
    }, this);

    _.each(OPTIONALS_OPT, function (item) {
      this['_' + item] = opts[item];
    }, this);
  },

  render: function () {
    this.clearSubViews();
    this.$el.html(template({
      name: this._name,
      avatar: this._avatar,
      role: this._role,
      description: this._description,
      canChangeReadAccess: this._canChangeReadAccess,
      hasReadAccess: this._hasReadAccess,
      hasWriteAccessAvailable: this._hasWriteAccessAvailable,
      canChangeWriteAccess: this._canChangeWriteAccess,
      hasWriteAccess: this._hasWriteAccess
    }));
    return this;
  },

  _onChangeWrite: function () {
    var p = this._permission;
    if (p.canChangeWriteAccess(this._model)) {
      if (p.hasWriteAccess(this._model)) {
        p.revokeWriteAccess(this._model);
      } else {
        p.grantWriteAccess(this._model);
      }
    }
  },

  _onChangeRead: function () {
    var p = this._permission;
    if (p.canChangeReadAccess(this._model)) {
      if (p.hasReadAccess(this._model)) {
        p.revokeAccess(this._model);
      } else {
        p.grantReadAccess(this._model);
      }
    }
  },

  _onHoverDisabledToggler: function (e) {
    var aclItem = this._permission.findRepresentableAclItem(this._model);
    var msg = this._inheritedAccessTooltipText(aclItem);
    var $el = $(e.currentTarget);

    if (aclItem && !aclItem.isOwn(this._model)) {
      this._tooltip = this._createTooltip({
        $el: $el,
        msg: msg
      });
      this._tooltip.showTipsy();
    }
  },

  _createTooltip: function (opts) {
    return new TipsyTooltipView({
      el: opts.$el,
      title: function () {
        return opts.msg;
      }
    });
  },

  _destroyTooltip: function () {
    if (this._tooltip) {
      this._tooltip.hideTipsy();
      this._tooltip.destroyTipsy();
    }
  },

  _inheritedAccessTooltipText: function (aclItem) {
    var type = aclItem.get('type');

    switch (type) {
      case 'group':
        return _t('components.modals.share-org.tooltip.group', {
          name: aclItem.get('entity').get('name')
        });
      case 'org':
        return _t('components.modals.share-org.tooltip.org');
      default:
        console.error('Trying to display inherited access for an unrecognized type ' + type);
        return '';
    }
  }

});
