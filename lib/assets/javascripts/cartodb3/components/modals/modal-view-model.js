var cdb = require('cartodb.js');

/**
 * View model of a modal
 */
module.exports = cdb.core.Model.extend({

  defaults: {
    show: true,
    createContentView: function () {
      return new cdb.core.View();
    }
  },

  createContentView: function () {
    return this.get('createContentView')(this);
  },

  show: function () {
    this.set('show', true);
  },

  hide: function () {
    this.set('show', false);
  },

  isHidden: function () {
    return !this.get('show');
  },

  /**
   * @override {Backbone.Model.prototype.destroy}
   */
  destroy: function () {
    this.trigger('destroy');
  }
});
