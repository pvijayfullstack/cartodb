var cdb = require('cartodb.js');
cdb.admin = require('cdb.admin');

/**
 *  Fake map card on dashboard
 */

module.exports = cdb.core.View.extend({

  className: 'MapsList-item',
  tagName: 'li',

  initialize: function() {
    this.template = cdb.templates.getTemplate('new_dashboard/views/fake_maps_item');
  },

  render: function() {
    this.$el.html(this.template());
    return this;
  }

});
