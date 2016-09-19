var _ = require('underscore');
var Backbone = require('backbone');
var syncAbort = require('./backbone/sync-abort');
var QueryRowsCollection = require('./query-rows-collection');

var template = _.template('SELECT * FROM (<%= sql %>) __wrapped');
var MAX_GET_LENGTH = 1024;
var STATUS = {
  unavailable: 'unavailable',
  unfetched: 'unfetched',
  fetching: 'fetching',
  fetched: 'fetched'
};

/**
 * Model to represent a schema of a SQL query.
 */
module.exports = Backbone.Model.extend({

  defaults: {
    query: '',
    sort_order: 'asc',
    rows_per_page: 0,
    page: 0,
    status: STATUS.unavailable // , unfetched, fetching, fetched
  },

  sync: syncAbort, // override {Backbone.prototype.sync} abort ongoing request if there is any

  initialize: function (attrs, opts) {
    if (!opts.configModel) throw new Error('configModel is required');

    this._configModel = opts.configModel;
    this.columnsCollection = new Backbone.Collection([]);
    this.rowsCollection = new QueryRowsCollection([]);

    if (this.get('status') === 'unavailable') {
      this._setStatusPerQueryValue();
    }

    this.on('change', this._onChange, this);
  },

  url: function () {
    return this._configModel.getSqlApiUrl();
  },

  isFetched: function () {
    return this.get('status') === STATUS.fetched;
  },

  canFetch: function () {
    return this.get('query') && !this.isFetched();
  },

  fetch: function (opts) {
    if (!this.canFetch()) return;

    this.set('status', STATUS.fetching);

    opts = opts || {};
    var errorCallback = opts && opts.error;

    opts.data = _.extend(
      opts.data || {},
      {
        sort_order: this.get('sort_order'),
        rows_per_page: this.get('rows_per_page'),
        page: this.get('page'),
        api_key: this._configModel.get('api_key'),
        q: this._getSqlApiQueryParam()
      }
    );

    opts.method = this._httpMethod();

    opts.error = function (model, response) {
      var error = response.responseText ? JSON.parse(response.responseText).error : [];
      errorCallback && errorCallback(error);
      this.set({
        query_errors: error,
        status: STATUS.unavailable
      });
    }.bind(this);

    return Backbone.Model.prototype.fetch.call(this, opts);
  },

  parse: function (r) {
    this.rowsCollection.reset(r.rows);

    this.columnsCollection.reset(
      _.map(r.fields, function (d, name) {
        return {
          name: name,
          type: d.type
        };
      })
    );

    return { status: STATUS.fetched };
  },

  /**
   * @override {Backbone.prototype.isNew} for this.destroy() to work (not try to send DELETE request)
   */
  isNew: function () {
    return true;
  },

  _onChange: function () {
    if (!this.hasChanged('status') && this.get('status') === 'fetching') {
      this.fetch(); // If is already fetching just redo the fetch with latest attrs
    } else {
      if (this.hasChanged('query')) {
        this.columnsCollection.reset();
        this._setStatusPerQueryValue();
      }
    }
  },

  _setStatusPerQueryValue: function () {
    this.set('status', this.get('query') ? 'unfetched' : 'unavailable');
  },

  resetDueToAlteredData: function () {
    this.set('status', 'unfetched');
    this.trigger('resetDueToAlteredData');
    this.fetch();
  },

  _getSqlApiQueryParam: function () {
    return template({
      sql: this.get('query')
    });
  },

  _httpMethod: function () {
    return this._getSqlApiQueryParam().length > MAX_GET_LENGTH
      ? 'POST'
      : 'GET';
  }

});
