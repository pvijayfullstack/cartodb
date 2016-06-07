var CoreView = require('backbone/core-view');
var template = require('./basemap-header.tpl');

module.exports = CoreView.extend({

  initialize: function (opts) {
    if (!opts.category) throw new Error('category is required');

    this.category = opts.category;
  },

  render: function () {
    this.$el.html(
      template({
        title: _t('editor.layers.basemap.title-label'),
        description: this.model.getName() + ' ' + _t('editor.layers.basemap.by') + ' ' + this.category
      })
    );
    return this;
  }

});
