var cdb = require('cartodb.js');

/**
 * Data library loading view, since data library is loaded async.
 */
module.exports = cdb.core.View.extend({

  render: function() {
    this.$el.html(
      cdb.templates.getTemplate('new_dashboard/templates/loading')({
        title: 'Your Data library is being stocked up',
        quote: 'Please wait while we load the list of Datasets in the Data library for you.'
      })
    );

    return this;
  },

  retrySoonAgainOrAbortIfLeavingLibrary: function(collection, routerModel) {
    var timeout;

    var abort = function() {
      clearTimeout(timeout);
      routerModel.unbind('all', abort);
      collection.unbind('reset', abort);
    };

    var retry = function() {
      timeout = setTimeout(function() {
        collection.bind('reset', abort);
        collection.fetch();
      }, 10000);
    };

    routerModel.bind('all', abort);
    retry();
  }
});
