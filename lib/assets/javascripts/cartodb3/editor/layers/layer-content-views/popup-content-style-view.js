var cdb = require('cartodb.js');
var template = require('./popup-content-style.tpl');

/**
 * Select for a Widget definition type.
 */
module.exports = cdb.core.View.extend({

  events: {
    'change .js-select': '_onTypeChange'
  },

  initialize: function (opts) {
  },

  render: function () {
    this.$el.html(template({
      title: _t('editor.layers.popup.style.title-label'),
      description: _t('editor.layers.popup.style.description')
    }));
    return this;
  },

  _onTypeChange: function (ev) {
    // TODO: persist
    // var newType = this.$('.js-select').val();
  }

});
