var template = require('./layer-analysis-ref-view.tpl');

/**
 * Reference to another layer.
 */
module.exports = cdb.core.View.extend({

  initialize: function (opts) {
    this.model.on('change', this.render, this);
  },

  render: function () {
    this.$el.html(template({
      letter: this.model.get('letter'),
      title: this.model.getName()
    }));

    return this;
  }
});
