var Backbone = require('backbone');
var _ = require('underscore');
var CustomListView = require('../../../custom-list/custom-view');
var CustomListCollection = require('../../../custom-list/custom-list-collection');
var template = require('./select.tpl');

Backbone.Form.editors.Select = Backbone.Form.editors.Base.extend({

  tagName: 'div',
  className: 'CustomSelect',

  events: {
    'click .js-button': '_onClick',
    focus: function (ev) {
      this.trigger('focus', this);
    },
    blur: function (ev) {
      this.trigger('blur', this);
    }
  },

  options: {
    disabled: false
  },

  initialize: function (opts) {
    this.options = _.extend(
      this.options,
      opts.schema.editorAttrs,
      {
        keyAttr: opts.key
      }
    );
    this.collection = new CustomListCollection(opts.schema.options);
    this._initViews();
    this.setValue(this.model.get(opts.key));
    Backbone.Form.editors.Base.prototype.initialize.call(this, opts);
    this._initBinds();
  },

  _initViews: function () {
    this.$el.html(
      template({
        name: this.value,
        disabled: this.options.disabled
      })
    );

    if (this.options.disabled) {
      this.undelegateEvents();
    }

    this._listView = new CustomListView({
      collection: this.collection,
      typeLabel: this.options.keyAttr
    });
    this.$el.append(this._listView.render().el);
  },

  _initBinds: function () {
    this.collection.bind('change:selected', this._onItemSelected, this);
    this.applyESCBind(function () {
      this._listView.hide();
    });
    this.applyClickOutsideBind(function () {
      this._listView.hide();
    });
  },

  _onItemSelected: function (mdl) {
    this.$('.js-button').text(mdl.getName());
    this._listView.hide();
    this.trigger('change', this);
  },

  _onClick: function () {
    this._listView.toggle();
  },

  getValue: function () {
    var item = this.collection.getSelectedItem();
    if (item) {
      return item.getValue();
    }
    return;
  },

  setValue: function (value) {
    var selectedModel = this.collection.setSelected(value);
    if (selectedModel) {
      this.$('.js-button').text(selectedModel.getName());
    }
    this.value = value;
  },

  remove: function () {
    this._listView && this._listView.clean();
    Backbone.Form.editors.Base.prototype.remove.call(this);
  }

});
