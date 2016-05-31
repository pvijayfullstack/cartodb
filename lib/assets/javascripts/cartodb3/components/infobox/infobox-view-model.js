var cdb = require('cartodb.js');

var INFOBOX_TYPE = {
  alert: 'is-alert',
  error: 'is-error',
  default: ''
};

var INFOBOX_BUTTON_TYPE = {
  link: 'link',
  button: 'button'
};

/**
 * View model of a infobox
 */

module.exports = cdb.core.Model.extend({

  defaults: {
    type: INFOBOX_TYPE.default,
    show: true,
    primaryButton: {
      type: INFOBOX_BUTTON_TYPE.link,
      label: 'Link'
    },
    secondaryButton: false
  },

  initialize: function (opts) {
    if (!!opts.primaryButton && !INFOBOX_BUTTON_TYPE[opts.primaryButton.type]) throw new Error('Type for primary button does not exist.');
    if (!!opts.primaryButton && !opts.primaryButton.action) throw new Error('Action for primary button is required.');
    if (!!opts.secondaryButton && !INFOBOX_BUTTON_TYPE[opts.secondaryButton.type]) throw new Error('Type for secondary button does not exist.');
    if (!!opts.secondaryButton && !opts.secondaryButton.action) throw new Error('Action for secondary button is required.');
  },

  title: function () {
    return this.get('title');
  },

  body: function () {
    return this.get('body');
  },

  type: function () {
    return INFOBOX_TYPE[this.get('type')] || INFOBOX_TYPE.default;
  },

  primaryButton: function () {
    return this.get('primaryButton');
  },

  secondaryButton: function () {
    return this.get('secondaryButton');
  },

  primaryAction: function () {
    var action = this.get('primaryButton').action;
    action && action();
  },

  secondaryAction: function () {
    var action = this.get('secondaryButton').action;
    action && action();
  }
});
