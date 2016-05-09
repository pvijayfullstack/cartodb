var cdb = require('cartodb.js');
var _ = require('underscore');
var Backbone = require('backbone');
require('../../../../components/form-components/index');
var StyleAnimatedFormModel = require('./style-animated-properties-form-model');

module.exports = cdb.core.View.extend({

  className: 'u-tSpace--m',

  initialize: function (opts) {
    if (!opts.layerDefinitionsCollection) throw new Error('layerDefinitionsCollection is required');
    if (!opts.layerTableModel) throw new Error('layerTableModel is required');
    if (!opts.styleModel) throw new Error('styleModel is required');

    this._layerTableModel = opts.layerTableModel;
    this._layerDefinitionsCollection = opts.layerDefinitionsCollection;
    this._styleModel = opts.styleModel;
  },

  render: function () {
    this._initAnimatedEnabler();
    return this;
  },

  _initAnimatedEnabler: function () {
    var alreadyTorqueLayer = this._layerDefinitionsCollection.isThereAnyTorqueLayer();
    var isAnimatedEnabled = this._styleModel.get('animated').enabled;

    this._enablerModel = new Backbone.Model({
      enabler: this._styleModel.get('animated').enabled
    });

    var enablerOpts = {
      model: this._enablerModel,
      title: _t('editor.style.components.animated-enabled.label'),
      key: 'enabler'
    };

    if (!isAnimatedEnabled) {
      _.extend(
        enablerOpts, {
          disabled: alreadyTorqueLayer,
          help: alreadyTorqueLayer ? _t('editor.style.components.animated-enabled.already-one-torque') : '',
        }
      );
    }

    this._enablerView = new Backbone.Form.editors.Enabler(enablerOpts);
    this._enablerModel.bind('change', this._setAnimatedFormView, this);

    this.$el.append(this._enablerView.render().el);
    this._setAnimatedFormView();
  },

  _setAnimatedFormView: function () {
    var isEnabled = this._enablerModel.get('enabler');
    if (isEnabled) {
      this._genAnimatedFormView();
    } else {
      this._removeAnimatedFormView();
    }

    var d = this._styleModel.get('animated');
    this._styleModel.set('animated', _.extend(d, { enabled: isEnabled }));
  },

  _genAnimatedFormView: function () {
    this._animatedFormModel = new StyleAnimatedFormModel({}, {
      layerTableModel: this._layerTableModel,
      styleModel: this._styleModel
    });

    this._animatedFormView = new Backbone.Form({
      className: 'Editor-formInner--nested',
      model: this._animatedFormModel
    });

    this._animatedFormView.bind('change', function () {
      this.commit();
    });

    this.$el.append(this._animatedFormView.render().el);
  },

  _removeAnimatedFormView: function () {
    if (this._animatedFormView) {
      this._animatedFormView.remove();
      this._animatedFormView.$el.empty();
    }
  },

  clean: function () {
    this._removeAnimatedFormView();
    cdb.core.View.prototype.clean.call(this);
  }
});
