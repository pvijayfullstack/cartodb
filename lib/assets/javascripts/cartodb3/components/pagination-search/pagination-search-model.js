var Backbone = require('backbone');

/**
 * Model representing the query string params for a "paged search" of a collection (matching the server-side APIs).
 *
 * @example usage
 *   var PagedSearch = require('common/paged_search_model');
 *   pagedSearch = new PagedSearch({ … })
 *   pagedSearch.fetch(collection) // => jqXHR, GET /collection/123?page=1&per_page20
 *   pagedSearch.set({ page: 2, per_page: 10, q: 'test' });
 *   pagedSearch.fetch(collection) // => GET /collection/123?page=2&per_page10&q=test
 */
module.exports = Backbone.Model.extend({

  defaults: {
    per_page: 20,
    page: 1
  },

  initialize: function (attrs, opts) {
    if (!opts.collection) throw new Error('collection is requires');
    this.collection = opts.collection;
  },

  fetch: function () {
    return this.collection.fetch({
      data: this.attributes
    });
  }
});
