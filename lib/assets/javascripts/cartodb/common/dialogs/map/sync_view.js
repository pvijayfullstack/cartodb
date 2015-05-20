var cdb = require('cartodb.js');
var BaseDialog = require('../../views/base_dialog/view');
var IntervalView = require('./sync/interval_view');

/**
 * Sync modal
 */
module.exports = BaseDialog.extend({

  _INTERVALS: [['Every hour', (60*60)], ['Every day', (60*60*24)], ['Every week', (60*60*24*7)], ['Every month', (60*60*24*30)], ['Never', 0]],

  initialize: function() {
    this.elder('initialize');

    if (!this.options.table) {
      throw new TypeError('table is required');
    }

    this.table = this.options.table;
    this._template = cdb.templates.getTemplate('common/dialogs/map/sync_view_template');

    this._setupModel();
    this._setupService();
    this._setupURL();
  },

  // implements cdb.ui.common.Dialog.prototype.render
  render: function() {
    this.clearSubViews();
    BaseDialog.prototype.render.call(this);
    this._initViews();
    return this;
  },

  // implements cdb.ui.common.Dialog.prototype.render
  render_content: function() {
    return this._template({
      service: this.service,
      url: this.url
    });
  },

  _initViews: function() {
    this._initIntervals();
  },

  _setupURL: function() {
    // Does it come from a datasource service (Dropbox, GDrive, ...)?
    if (this.table.synchronization.get('service_name') || this.table.synchronization.get('service_item_id')) {
      this.url = this.table.synchronization.get('service_item_id');
    }

  },

  _setupService: function() {
    this.service = this.table.synchronization.get('service_name');
    // If service exists, let's capitalize it!
    if (this.service && _.isString(this.service)) {
      this.service = this.service.charAt(0).toUpperCase() + this.service.slice(1);
    }
  },

  _initIntervals: function() {
    this._intervals = new Backbone.Collection();

    _.each(this._INTERVALS, function(interval) {
      this._intervals.add({ name: interval[0], interval: interval[1], checked: this.table.synchronization.get("interval") === interval[1] });
    }, this);

    this._intervals.each(function(interval) {
      var view = new IntervalView({ model: interval });
      view.bind("checked", this._onIntervalChecked, this);
      this.$(".js-intervals").append(view.render().$el);
      this.addView(view);
    }, this);
  },

  _onIntervalChecked: function(interval) {
    this._intervals.each(function(i) {
      if (interval.get("interval") !== i.get("interval")) {
        i.set("checked", false);
      }
    }, this);
  },

  _getSelectedInterval: function() {
    return this._intervals.find(function(interval) {
      return interval.get("checked")
    });
  },

  _setupModel: function() {
    this.model = new cdb.core.Model({
      option: 'interval',
      interval: this.table.synchronization.get('interval')
    });
  },

  _addTab: function(name, view) {
    this._contentPane.addTab(name, view.render());
    this.addView(view);
  },

  _ok: function() {
    var selectedInterval = this._getSelectedInterval();

    if (selectedInterval) {

      var interval = selectedInterval.get('interval');

      if (interval) {
        this.table.synchronization.save({
          interval: interval
        });
      } else {
        this.table.synchronization.destroy();
      }
    }

    this.close();
  }

});
