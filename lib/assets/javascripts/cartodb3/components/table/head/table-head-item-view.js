var CoreView = require('backbone/core-view');
var template = require('./table-head-item.tpl');

/*
 *  Main table view
 */

module.exports = CoreView.extend({

  className: 'Table-headItem',
  tagName: 'th',

  render: function () {
    this.clearSubViews();
    this.$el.html(
      template({
        name: this.model.get('name'),
        type: this.model.get('type'),
        geometry: this.options.simpleGeometry
      })
    );
    return this;
  }

});
