var cdb = require('cartodb.js');
var _ = require('underscore');
var Backbone = require('backbone');
require('../../../../components/form-components/index');
var StyleLabelsFormModel = require('./style-labels-properties-form-model');
var template = require('./style-properties-form.tpl');

module.exports = cdb.core.View.extend({

  initialize: function (opts) {
    if (!opts.layerTableModel) throw new Error('layerTableModel is required');
    if (!opts.styleModel) throw new Error('styleModel is required');

    this._layerTableModel = opts.layerTableModel;
    this._styleModel = opts.styleModel;
  },

  render: function () {
    this.$el.html(template());

    this._initLabelsEnabler();

    return this;
  },

  _initLabelsEnabler: function () {
    this._enablerModel = new Backbone.Model({
      enabler: this._styleModel.get('labels').enabled
    });
    this._enablerView = new Backbone.Form.editors.Enabler({
      className: 'js-labelsEnabler',
      model: this._enablerModel,
      title: 'hello',
      key: 'enabler'
    });

    this._enablerModel.bind('change', this._setLabelsFormView, this);
    this._setLabelsFormView();
    this.$('.js-propertiesForm').append(this._enablerView.render().el);
  },

  _setLabelsFormView: function () {
    var isEnabled = this._enablerModel.get('enabler');
    if (isEnabled) {
      this._genLabelsFormView();
    } else {
      this._removeLabelsFormView();
    }

    var d = this._styleModel.get('labels');
    this._styleModel.set('labels', _.extend(d, { enabled: isEnabled }));
  },

  _genLabelsFormView: function () {
    this._labelsFormModel = new StyleLabelsFormModel({}, {
      layerTableModel: this._layerTableModel,
      styleModel: this._styleModel
    });

    this._labelsFormView = new Backbone.Form({
      className: 'Editor-formInner--nested',
      model: this._labelsFormModel
    });

    this._labelsFormView.bind('change', function () {
      this.commit();
    });

    this.$('.js-labelsEnabler').insertAfter(this._labelsFormView.render().el);
  },

  _removeLabelsFormView: function () {
    if (this._labelsFormView) {
      this._labelsFormView.remove();
      this._labelsFormView.$el.empty();
    }
  },

  clean: function () {
    this._removeShapeFormView();
    this._removeAnimatedFormView();
    this._removeLabelsFormView();
    cdb.core.View.prototype.clean.call(this);
  }
});
