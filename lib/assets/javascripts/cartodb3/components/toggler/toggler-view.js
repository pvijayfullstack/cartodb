var cdb = require('cartodb.js');
var template = require('./toggler.tpl');

module.exports = cdb.core.View.extend({

  className: 'Toggle',

  events: {
    'click .js-input': '_onClick'
  },

  initialize: function (opts) {
    if (!opts.collection) {
      throw new Error('Collection should be provided');
    }

    this.listenTo(this.collection, 'change', this.render);
    this._labels = this.collection.map(function (m) {
      return m.get('label');
    });

    this.render();
  },

  render: function () {
    var checked = this.collection.at(1).get('selected');

    this.$el.html(
      template({
        labels: this._labels,
        checked: checked
      })
    );
    return this;
  },

  _onClick: function () {
    var index = this.$('.js-input').prop('checked') ? 1 : 0;
    this.collection.at(index).set({selected: true});
    this.collection.trigger('toggle');
  }
});
