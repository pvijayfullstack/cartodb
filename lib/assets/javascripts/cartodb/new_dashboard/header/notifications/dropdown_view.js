var cdb = require('cartodb.js');
cdb.admin = require('cdb.admin');


/**
 * 
 */

module.exports = cdb.admin.DropdownMenu.extend({

  initialize: function() {
    cdb.admin.DropdownMenu.prototype.initialize.apply(this, arguments);
    this._initBinds();
  },

  render: function() {
    this.$el.html(this.template_base({
      items:        this.collection.toJSON(),
      unreadItems:  this.collection.filter(function(item){ return !item.get('opened') }).length
    }));
    
    $('body').append(this.el);

    return this;
  },

  _initBinds: function() {
    cdb.god.bind('closeDialogs', this.hide, this);
    this.add_related_model(cdb.god);
  }
});
