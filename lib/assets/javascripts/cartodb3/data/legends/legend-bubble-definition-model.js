var _ = require('underscore');
var LegendBaseDefModel = require('./legend-base-definition-model');
var LegendColorHelper = require('./legend-color-helper');

module.exports = LegendBaseDefModel.extend({
  defaults: {
    type: 'bubble',
    color: '#fabada'
  },

  initialize: function (attrs, opts) {
    this._titlePlaceholder = _t('editor.legend.legend-form.by-size');
    LegendBaseDefModel.prototype.initialize.call(this, attrs, opts);

    this.on('change:fill', function () {
      this.set('fillColor', this.get('fill').color.fixed);
      this.set('color', this.get('fill').color.fixed);
    }, this);

    this._inheritColor();
  },

  toJSON: function () {
    return _.extend(
      {},
      _.omit(this.attributes, 'fill'),
      {
        fillColor: this.get('fill').color.fixed
      }
    );
  },

  _inheritColor: function () {
    var color = this.layerDefinitionModel.styleModel.get('fill').color;
    var fill = LegendColorHelper.getBubbles(color);
    this.set({fill: fill});
  },

  _generateSchema: function () {
    var schema = LegendBaseDefModel.prototype._generateSchema.call(this);
    return _.extend(
      schema,
      {
        fill: {
          type: 'Fill',
          title: _t('editor.legend.legend-form.fill'),
          options: [],
          editorAttrs: {
            color: {
              hidePanes: ['value']
            }
          }
        }
      }
    );
  }
});
