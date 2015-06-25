var Backbone = require('backbone');
var _ = require('underscore');
var pollTimer = 2000;

/**
 *  Geocoding model
 *
 */

module.exports = cdb.core.Model.extend({

  options: {
    startPollingAutomatically: true
  },

  defaults: {
    kind: '',
    formatter: '',
    table_name: '',
    state: ''
  },

  url: function(method) {
    var version = cdb.config.urlVersion('geocoding', method);

    var base = '/api/' + version + '/geocodings/';
    if (this.isNew()) {
      return base;
    }
    return base + this.id;
  },

  setUrlRoot: function(urlRoot) {
    this.urlRoot = urlRoot;
  },

  initialize: function(opts) {
    this._initBinds();
    _.extend(this.options, opts);
    if (this.options.startPollingAutomatically) {
      this._checkModel();  
    }
  },

  _initBinds: function() {
    this.bind('change:id', this._checkModel, this);
    this.bind('change:state', this._checkState, this);
  },

  _checkModel: function() {
    var self = this;

    if (this.get('id')) {
      this.pollCheck();
    } else {
      this._saveModel();
    }
  },

  _saveModel: function() {
    var self = this;
    if (this.isNew()) {
      this.save({}, {
        error: function() {
          self.set({
            state: 'failed',
            error: {
              title: 'Oops, there was a problem',
              description: 'Unfortunately there was an error starting the geocoder'
            }
          });
        }
      });
    }
  },

  // checks for poll to finish
  pollCheck: function(i) {
    var self = this;

    if (this.pollTimer) {
      return false;
    }

    this.pollTimer = setInterval(function() {
      self.fetch({
        error: function(e) {
          self.trigger("change");
        }
      });
    }, pollTimer);
  },

  destroyCheck: function() {
    clearInterval(this.pollTimer);
    delete this.pollTimer;
  },

  _checkState: function() {
    var state = this.get('state');
    if (this.hasFailed() || this.hasCompleted()) {
      this.destroyCheck();
    }
  },

  getError: function() {
    return this.get('error');
  },

  hasFailed: function() {
    var state = this.get('state');
    return state === "failed" || state === "reset" || state === "cancelled"
  },

  hasCompleted: function() {
    return this.get('state') === "finished"
  },

  isOngoing: function() {
    return !this.hasCompleted() && !this.hasFailed()
  },

  cancelGeocoding: function() {
    this.destroyCheck();
    this.save({ state: 'cancelled' }, { wait:true });
  },

  resetGeocoding: function() {
    this.destroyCheck();
    this.set('state', 'reset');
  }

});
