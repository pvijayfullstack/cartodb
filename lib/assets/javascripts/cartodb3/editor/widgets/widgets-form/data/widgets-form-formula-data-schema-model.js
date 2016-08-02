var Backbone = require('backbone');

module.exports = Backbone.Model.extend({

  defaults: {
    schema: {}
  },

  initialize: function (attrs, opts) {
    if (!opts.columnOptionsFactory) throw new Error('columnOptionsFactory is required');

    this._columnOptionsFactory = opts.columnOptionsFactory;
  },

  updateSchema: function () {
    var columnOptions = this._columnOptionsFactory.create(this.get('column'), this._isNumberType);

    this.schema = {
      column: {
        type: 'Select',
        title: _t('editor.widgets.widgets-form.data.column'),
        help: this._columnOptionsFactory.unavailableColumnsHelpMessage(),
        options: columnOptions,
        editorAttrs: {
          disabled: this._columnOptionsFactory.areColumnsUnavailable()
        }
      },
      operation: {
        type: 'Select',
        title: _t('editor.widgets.widgets-form.data.operation'),
        options: ['min', 'max', 'count', 'avg', 'sum']
      },
      suffix: {
        title: _t('editor.widgets.widgets-form.data.suffix'),
        type: 'Text'
      },
      prefix: {
        title: _t('editor.widgets.widgets-form.data.prefix'),
        type: 'Text'
      }
    };
  },

  canSave: function () {
    return !!this.get('column');
  },

  _isNumberType: function (m) {
    return m.get('type') === 'number';
  }

});
