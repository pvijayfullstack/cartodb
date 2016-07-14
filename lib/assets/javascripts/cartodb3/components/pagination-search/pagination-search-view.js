var Backbone = require('backbone');
var CoreView = require('backbone/core-view');
var _ = require('underscore');
var PaginationModel = require('../pagination/pagination-model');
var PaginationSearchModel = require('./pagination-search-model');
var renderLoading = require('../loading/render-loading');
var ErrorView = require('../error/error-view');
var template = require('./pagination-search.tpl');
var Utils = require('../../helpers/utils');
var PaginationView = require('../pagination/pagination-view');

/**
 * View to render a searchable/pageable collection.
 * Also allows to filter/search list.
 *
 * - collection is a collection which has a PagedSearchModel.
 */

var REQUIRED_OPTS = [
  'listCollection',
  'createContentView'
];

var ENTER_KEY_CODE = 13;
var ESCAPE_KEY_CODE = 27;

module.exports = CoreView.extend({

  events: {
    'click .js-search-link': '_onSearchClick',
    'click .js-clean-search': '_onCleanSearchClick',
    'keydown .js-search-input': '_onKeyDown'
  },

  initialize: function (opts) {
    _.each(REQUIRED_OPTS, function (item) {
      if (!opts[item]) throw new Error(item + ' is required');
      this['_' + item] = opts[item];
    }, this);

    this._paginationModel = new PaginationModel({
      current_page: 1
    });

    this._paginationSearchModel = new PaginationSearchModel({}, {
      collection: this._listCollection
    });

    this._stateModel = new Backbone.Model({
      state: 'idle'
    });

    this._initBinds();
    this._initPagination();
    this._paginationSearchModel.fetch();
  },

  render: function () {
    this.clearSubViews();
    this.$el.html(template({
      q: this._paginationSearchModel.get('q')
    }));
    this._initViews();
    return this;
  },

  _initBinds: function () {
    this._paginationSearchModel.on('fetching', this._updateStateLoading, this);
    this._paginationSearchModel.on('fetched', this._updateStateFetched, this);
    this._paginationSearchModel.on('error', this._updateStateError, this);
    this._stateModel.on('change:state', this.render, this);
    this.add_related_model(this._paginationSearchModel);
    this.add_related_model(this._stateModel);
  },

  _updatePaginationModelByCollection: function () {
  },

  _updateStateError: function () {
    this._stateModel.set('state', 'error');
  },

  _updateStateLoading: function () {
    this._stateModel.set('state', 'loading');
  },

  _updateStateFetched: function () {
    this._paginationModel.set({
      per_page: this._paginationSearchModel.get('per_page'),
      total_count: this._listCollection.totalCount()
    });
    this._stateModel.set('state', 'show');
  },

  _initPagination: function () {
    this._paginationView = new PaginationView({
      className: 'Pagination Pagination--search',
      model: this._paginationModel
    });
    this.addView(this._paginationView);
  },

  _initViews: function () {
    var state = this._stateModel.get('state');
    var view;

    this.$el.append(this._paginationView.render().el);

    if (state === 'loading') {
      this._content().html(renderLoading({
        title: 'Fetching'
      }));
    }

    if (state === 'error') {
      var errorView = new ErrorView({
        title: 'Error',
        desc: 'Oops there was an error.'
      });
      this._content().html(errorView.render().el);
      this.addView(errorView);
    }

    if (state === 'show') {
      view = this._createContentView();
      this._content().html(view.render().el);
      this.addView(view);
    }
  },

  _focusSearchInput: function () {
    this._searchInput().focus().val();
  },

  _onSearchClick: function (e) {
    this.killEvent(e);
    this._searchInput().focus();
  },

  _onCleanSearchClick: function (e) {
    this.killEvent(e);
    this._cleanSearch();
  },

  _onKeyDown: function (e) {
    if (e.which === ENTER_KEY_CODE) {
      this.killEvent(e);
      this._submitSearch();
    } else if (e.which === ESCAPE_KEY_CODE) {
      if (this._paginationSearchModel.get('q')) {
        this.killEvent(e);
        this._cleanSearch();
      }
    }
  },

  _submitSearch: function (e) {
    this._makeNewSearch(Utils.stripHTML(this._searchInput().val().trim()));
  },

  _cleanSearch: function () {
    this._searchInput().val('');
    this._makeNewSearch('');
  },

  _makeNewSearch: function (query) {
    this._paginationSearchModel.set({
      q: query,
      page: 1
    });

    this._paginationSearchModel.fetch();
  },

  _searchInput: function () {
    return this.$('.js-search-input');
  },

  _cleanSearchBtn: function () {
    return this.$('.js-clean-search');
  },

  _content: function () {
    return this.$('.js-content');
  }

});
