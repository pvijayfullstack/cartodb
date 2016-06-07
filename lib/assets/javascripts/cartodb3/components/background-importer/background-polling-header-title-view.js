var CoreView = require('backbone/core-view');
var template = require('./background-polling-header-title.tpl');

/**
 *  Background polling header title view
 *
 *  It will contain only the title
 *
 */
module.exports = CoreView.extend({

  tagName: 'h3',
  className: 'BackgroundPolling-headerTitle CDB-Text CDB-Size-large u-mainTextColor',

  initialize: function () {
    this._initBinds();
  },

  render: function () {
    this.$el.html(
      template({
        imports: this.model.getTotalImports(),
        geocodings: this.model.getTotalGeocodings(),
        totalPollings: this.model.getTotalPollings()
      })
    );

    return this;
  },

  _initBinds: function () {
    this.model.bind('change analysisAdded analysisRemoved importAdded importRemoved geocodingAdded geocodingRemoved', this.render, this);
  }
});
