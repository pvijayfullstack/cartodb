var cdb = require('cartodb.js');
var cdbAdmin = require('cdb.admin');
var pollTimer = 5000; // Interval time between poll checkings
var multiply = 1.2;  // Multiply interval for this number

/** 
 *  New import model that controls
 *  the state of an import
 *
 */

module.exports = cdb.core.Model.extend({

  idAttribute: 'item_queue_id',
  
  urlRoot: '/api/v1/imports',

  initialize: function() {
    this._initBinds();
  },

  _initBinds: function() {
    this.bind('change:state', this._checkState, this);
    this.bind('change:success', this._checkState, this);
    this.bind('change:item_queue_id', this._checkQueueId, this);
  },

  createImport: function(data) {
    var d = this._prepareData(data);

    this[ data.interval > 0 ? '_createSyncImport' : '_createRegularImport'](d);
  },

  _checkState: function() {
    var state = this.get('state');
    if (state === "complete" || state === "failure") {
      this.destroyCheck();
    }
  },

  _checkQueueId: function() {
    if (this.get('item_queue_id')) {
      this.pollCheck();
    }
  },

  _prepareData: function(data) {
    var d = {
      type_guessing:    data.type_guessing,
      content_guessing: data.content_guessing,
      interval:         data.interval,
      create_vis:       true
    };
    var type = data.type;
    var option = data.option;

    // Url?
    if (type === "url") {
      _.extend(d, {
        url: data.value
      });
    }

    // Remote?
    if (type === "remote") {
      _.extend(d, {
        remote_visualization_id: data.remote_visualization_id,
        value: data.value
      });
    }

    // Service?
    if (type === "service") {
      // If service is Twitter, service_item_id should be
      // sent stringified
      var service_item_id = (option === "twitter")
          ? JSON.stringify(data.service_item_id)
          : data.service_item_id;

      _.extend(d, {
        value:            data.value,
        service_name:     data.service_name,
        service_item_id:  service_item_id
      });
    }

    return d;
  },

  _createSyncImport: function(d) {
    var self = this;
    // Create synchronization model
    var sync = new cdbAdmin.TableSynchronization(d);

    sync.save(null, {
      success: function(m) {
        self.set('item_queue_id', m.get('data_import').item_queue_id);
      },
      error: function() {
        self.set(
          'get_text_error',
          {
            title: 'There was an error',
            what_about: 'Unfortunately there was an error creating the synchronization'
          }
        );
      }
    });
  },

  _createRegularImport: function(d) {
    var self = this;

    this.save(d, {
      error: function() {
        self.set(
          'get_text_error',
          {
            title: 'There was an error',
            what_about: 'Unfortunately there was an error starting the import'
          }
        );
      }
    });
  },

  pollCheck: function() {
    if (this.pollTimer) return;
    var self = this;

    this.pollTimer = setInterval(request, pollTimer);

    function request() { 
      self.destroyCheck();

      self.fetch();

      pollTimer = pollTimer * multiply;

      self.pollTimer = setInterval(request, pollTimer);
    }

    // Start doing a fetch
    self.fetch();
  },

  destroyCheck: function() {
    clearInterval(this.pollTimer);
    delete this.pollTimer;
  }

});