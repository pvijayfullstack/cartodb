var _ = require('underscore');
var Backbone = require('backbone');
var cdb = require('cartodb.js');
var ErrorView = require('../../error/error-view');
var createTuplesItems = require('./create-tuples-items');
var widgetsTypes = require('./widgets-types');
var BodyView = require('./body-view');
var template = require('./add-widgets.tpl');
var renderLoading = require('../../../components/loading/render-loading');

/**
 * View to add new widgets.
 * Expected to be rendered in a modal.
 *
 * The widget options to choose from needs to be calculated from columns derived from the available layers,
 * which may be async, so the actual options can not be created until after the layers' columns are fetched.
 */
module.exports = cdb.core.View.extend({
  className: 'Dialog-content Dialog-content--expanded',

  events: {
    'click .js-continue': '_onContinue'
  },

  initialize: function (opts) {
    if (!opts.modalModel) throw new Error('modalModel is required');
    if (!opts.layerDefinitionsCollection) throw new Error('layerDefinitionsCollection is required');
    if (!opts.widgetDefinitionsCollection) throw new Error('widgetDefinitionsCollection is required');

    this._modalModel = opts.modalModel;
    this._layerDefinitionsCollection = opts.layerDefinitionsCollection;
    this._widgetDefinitionsCollection = opts.widgetDefinitionsCollection;
    this._optionsCollection = new Backbone.Collection();

    this._analysisDefinitionNodesCollection = this._layerDefinitionsCollection.getAnalysisDefinitionNodesCollection();

    if (!this._hasFetchedAllQuerySchemas()) {
      var isNotFetched = _.compose(_.negate(Boolean), this._isFetched);
      this._analysisQuerySchemasChain()
        .filter(isNotFetched)
        .each(function (m) {
          this.listenToOnce(m, 'sync', this._onAnalysisQuerySchemaFetched);
          this.listenToOnce(m, 'error', this._onAnalysisQuerySchemaFetchError);
          m.fetch();
        }, this);
    }

    this.listenTo(this._optionsCollection, 'change:selected', this._updateContinueButtonState);
  },

  render: function () {
    this.clearSubViews();
    this.$el.html(template());

    if (this._hasFetchedAllQuerySchemas()) {
      this._renderBodyView();
    } else if (this._failedFetch) {
      this._renderErrorView();
    } else {
      this._renderLoadingView();
    }

    this._updateContinueButtonState();

    return this;
  },

  _onContinue: function () {
    var selectedOptionModels = this._optionsCollection.filter(this._isSelected);

    if (selectedOptionModels.length > 0) {
      _.map(selectedOptionModels, function (m) {
        m.createUpdateOrSimilar(this._widgetDefinitionsCollection);
      }, this);

      // for now assumes all widgets are created fine
      // TODO show loading again, indicate creation status
      // TODO error handling
      this._modalModel.destroy();
    }
  },

  _isFetched: function (m) {
    return !!m.get('fetched');
  },

  _hasFetchedAllQuerySchemas: function () {
    return this._analysisQuerySchemasChain()
      .all(this._isFetched)
      .value();
  },

  _analysisQuerySchemasChain: function () {
    return this._analysisDefinitionNodesCollection
    .chain()
    .reduce(function (memo, m) {
      m = m.querySchemaModel;
      if (m.get('query') && m.get('status') === 'ready') {
        memo.push(m);
      }
      return memo;
    }, []);
  },

  _onAnalysisQuerySchemaFetched: function () {
    if (this._hasFetchedAllQuerySchemas()) {
      this.render();
    }
  },

  _onAnalysisQuerySchemaFetchError: function () {
    this._failedFetch = true;
    this.render();
  },

  _renderBodyView: function () {
    this._createOptionsModels();
    var view = new BodyView({
      el: this._$body(),
      optionsCollection: this._optionsCollection,
      widgetsTypes: widgetsTypes
    });
    this.addView(view.render());
  },

  _renderLoadingView: function () {
    this._$body().html(
      renderLoading({
        title: _t('components.modals.add-widgets.loading-title')
      })
    );
  },

  _renderErrorView: function () {
    var view = new ErrorView();
    this._$body().append(view.render().el);
    this.addView(view);
  },

  _$body: function () {
    return this.$('.js-body');
  },

  _updateContinueButtonState: function () {
    this.$('.js-continue').toggleClass('is-disabled', !this._optionsCollection.any(this._isSelected));
  },

  _isSelected: function (m) {
    return !!m.get('selected');
  },

  _createOptionsModels: function () {
    var tuplesItems = createTuplesItems(this._analysisDefinitionNodesCollection, this._layerDefinitionsCollection);

    _.each(widgetsTypes, function (d) {
      var models = d.createOptionModels(tuplesItems, this._widgetDefinitionsCollection);
      this._optionsCollection.add(models);
    }, this);
  }
});
