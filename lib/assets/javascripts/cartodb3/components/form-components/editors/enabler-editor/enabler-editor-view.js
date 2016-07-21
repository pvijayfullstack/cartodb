var Backbone = require('backbone');
var $ = require('jquery');
var _ = require('underscore');
var template = require('./enabler-editor.tpl');

/**
 *  Creates an element that enables another component, tested with:
 *
 *  select, number and input so far.
 */

Backbone.Form.editors.EnablerEditor = Backbone.Form.editors.Base.extend({

  tagName: 'div',
  className: 'Editor-checker u-flex u-alignCenter',

  events: {
    'click .js-check': '_onCheckClicked'
  },

  initialize: function (opts) {
    Backbone.Form.editors.Base.prototype.initialize.call(this, opts);
    this._setOptions(opts);

    this._editorOptions = opts.schema.editor;
    this._checkModel = new Backbone.Model({
      enabled: this.model.get(opts.key)
    });
    this.template = template;

    this._initViews();
    this._initBinds();
  },

  _initBinds: function () {
    this._checkModel.bind('change:enabled', function (mdl, isEnabled) {
      this.model.set(this.options.keyAttr, '');
      this._triggerChange();
      this._renderComponent();
    }, this);
  },

  _initViews: function () {
    this.$el.html(
      this.template({
        label: this.options.label,
        isChecked: this._isChecked()
      })
    );

    this._renderComponent();
  },

  _isChecked: function () {
    return this._checkModel.get('enabled');
  },

  _renderComponent: function () {
    if (this._editorComponent) {
      this._editorComponent.remove();
    }

    if (this._editorOptions) {
      var EditorClass = Backbone.Form.editors[this._editorOptions.type];
      var editorAttrs = _.extend(
        this._editorOptions.editorAttrs || {},
        {
          disabled: !this._isChecked()
        }
      );

      this._editorComponent = new EditorClass(
        _.extend(
          {
            model: this.model,
            key: this.options.keyAttr,
            editorAttrs: editorAttrs
          },
          _.omit(this._editorOptions, 'editorAttrs', 'type')
        )
      );
      this._editorComponent.bind('change', this._setEditorComponentValue, this);
      this.$('.js-editor').html(this._editorComponent.render().el);
      this._setEditorComponentValue();
    }
  },

  _setEditorComponentValue: function () {
    this._triggerChange();
    this._editorComponent.commit();
  },

  _triggerChange: function () {
    this.trigger('change', this);
  },

  getValue: function () {
    if (this._editorComponent) {
      return this._editorComponent.getValue();
    } else {
      return '';
    }
  },

  setValue: function (value) {
    this._checkModel.set('enabled', !!value);
    if (this._editorComponent) {
      this._editorComponent.setValue(value);
    }
  },

  _onCheckClicked: function (ev) {
    this._checkModel.set('enabled', $(ev.target).is(':checked'));
  },

  remove: function () {
    if (this._editorComponent) {
      this._editorComponent.remove();
    }
    Backbone.Form.editors.Base.prototype.remove.call(this);
  }

});
