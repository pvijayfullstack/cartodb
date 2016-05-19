var cdb = require('cartodb.js');
var _ = require('underscore');
var StyleFormView = require('./style-form/style-form-view');
var StylesFactory = require('./styles-factory');
var CarouselFormView = require('../../components/carousel-form-view');
var CarouselCollection = require('../../components/custom-carousel/custom-carousel-collection');

module.exports = cdb.core.View.extend({

  events: {
    'click .js-new-analysis': '_openAddAnalysis'
  },

  initialize: function (opts) {
    if (!opts.layerDefinitionsCollection) throw new Error('layersDefinitionCollection is required');
    if (!opts.layerDefinitionModel) throw new Error('layerDefinitionModel is required');
    if (!opts.querySchemaModel) throw new Error('querySchemaModel is required');
    if (!opts.modals) throw new Error('modals is required');

    this._layerDefinitionsCollection = opts.layerDefinitionsCollection;
    this._layerDefinitionModel = opts.layerDefinitionModel;
    this._styleModel = this._layerDefinitionModel.styleModel;
    this._modals = opts.modals;
    this._querySchemaModel = opts.querySchemaModel;

    if (this._querySchemaModel.get('status') === 'unfetched') {
      this._listenQuerySchemaModelChanges();
      this._querySchemaModel.fetch();
    }

    // Render everything when there is an undo/redo action
    this._styleModel.bind('undo redo', this.render, this);
    this._styleModel.bind('change', this._onStyleChange, this);
    this.add_related_model(this._styleModel);
  },

  render: function () {
    this.clearSubViews();
    this.$el.empty();
    this._renderCarousel();
    this._renderForm();
    return this;
  },

  _onStyleChange: function () {
    this._layerDefinitionModel.save();
  },

  _listenQuerySchemaModelChanges: function () {
    this._querySchemaModel.bind('change:status', function (status) {
      if (this._querySchemaModel.get('status') === 'fetched') {
        this.render();
      }
    }, this);
    this.add_related_model(this._querySchemaModel);
  },

  _renderCarousel: function () {
    var carouselCollection = new CarouselCollection(
      _.map(StylesFactory.getStyleTypes(this._styleModel.get('type'), this._getCurrentSimpleGeometryType()), function (type) {
        return {
          selected: this._styleModel.get('type') === type.value,
          val: type.value,
          label: type.label,
          template: function () {
            return type.value;
          }
        };
      }, this)
    );

    carouselCollection.bind('change:selected', function (mdl) {
      if (mdl.get('selected')) {
        this._styleModel.setDefaultPropertiesByType(mdl.getValue(), this._getCurrentSimpleGeometryType());
      }
    }, this);

    var view = new CarouselFormView({
      collection: carouselCollection,
      template: require('./style-form-types.tpl')
    });
    this.addView(view);
    this.$el.append(view.render().el);
  },

  _getCurrentSimpleGeometryType: function () {
    var geom = this._querySchemaModel.getGeometry();
    return geom ? geom.getSimpleType() : 'point';
  },

  _renderForm: function () {
    if (this._styleForm) {
      this._styleForm.clean();
      this.removeView(this._styleForm);
    }

    this._styleForm = new StyleFormView({
      layerDefinitionsCollection: this._layerDefinitionsCollection,
      styleModel: this._styleModel,
      querySchemaModel: this._querySchemaModel
    });
    this.$el.append(this._styleForm.render().el);
    this.addView(this._styleForm);
  }

});
