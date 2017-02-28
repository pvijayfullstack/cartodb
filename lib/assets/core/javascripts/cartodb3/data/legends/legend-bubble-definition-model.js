var _ = require('underscore');
var LegendBaseDefModel = require('./legend-base-definition-model');
var LegendColorHelper = require('../../editor/layers/layer-content-views/legend/form/legend-color-helper');
var DEFAULT_BUBBLES_COLOR = '#999999';

module.exports = LegendBaseDefModel.extend({
  defaults: _.extend({}, LegendBaseDefModel.prototype.defaults,
    {
      type: 'bubble',
      fillColor: null,
      topLabel: '',
      bottomLabel: ''
    }
  ),

  initialize: function (attrs, opts) {
    LegendBaseDefModel.prototype.initialize.call(this, attrs, opts);
    this._initBinds();
  },

  parse: function (r, opts) {
    var attrs = LegendBaseDefModel.prototype.parse.call(this, r);

    if (opts.layerDefinitionModel) {
      if (r.definition) {
        attrs.fillColor = r.definition.color;
        attrs.topLabel = r.definition.top_label;
        attrs.bottomLabel = r.definition.bottom_label;
      } else {
        attrs.fillColor = this._inheritStyleColor(opts.layerDefinitionModel.styleModel);
      }
    }
    return attrs;
  },

  _initBinds: function () {
    this.listenTo(this.layerDefinitionModel, 'change:cartocss', this._onChangeStyle.bind(this));
    this.listenTo(this.layerDefinitionModel.styleModel, 'style:update', this._onChangeStyle.bind(this));
  },

  _onChangeStyle: function () {
    var styleModel = this.layerDefinitionModel.styleModel;
    if (!this.layerDefinitionModel.get('autoStyle') && !styleModel.hasNoneStyles()) {
      this.set('fillColor', this._inheritStyleColor(styleModel));
    }
  },

  toJSON: function () {
    return _.extend(
      {},
      _.omit(this.attributes, 'fill', 'fillColor', 'topLabel', 'bottomLabel', 'postHTMLSnippet', 'preHTMLSnippet', 'customState'),
      {
        pre_html: this.get('preHTMLSnippet'),
        post_html: this.get('postHTMLSnippet')
      },
      {
        conf: {
          columns: this.get('customState')
        }
      },
      {
        definition: {
          color: this.get('fillColor'),
          top_label: this.get('topLabel'),
          bottom_label: this.get('bottomLabel')
        }
      }
    );
  },

  _inheritStyleColor: function (styleModel) {
    var fill = styleModel.get('fill');
    var stroke = styleModel.get('stroke');
    var color = (fill && fill.color) || (stroke && stroke.color);
    return (color && LegendColorHelper.getBubbles(color).color.fixed) || DEFAULT_BUBBLES_COLOR;
  }
});
