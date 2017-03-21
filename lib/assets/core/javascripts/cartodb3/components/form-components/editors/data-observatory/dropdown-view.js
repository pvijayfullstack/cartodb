var Backbone = require('backbone');
var template = require('./dropdown.tpl');
var selectedItemTemplate = require('./dropdown-item.tpl');
var DropdownDialogView = require('./dropdown-dialog-view');
var PopupManager = require('../../../popup-manager');
var MeasurementsCollection = require('./measurements-collection');
var FiltersCollection = require('./measurements-filters-collection');

var ENTER_KEY_CODE = 13;
var STATE = {
  idle: 'idle',
  loading: 'loading',
  fetching: 'fetching',
  fetched: 'fetched',
  error: 'error'
};

Backbone.Form.editors.DataObservatoryDropdown = Backbone.Form.editors.Base.extend({

  tagName: 'div',
  className: 'u-ellipsis Editor-formSelect',

  events: {
    'click .js-button': '_onButtonClick',
    'keydown .js-button': '_onButtonKeyDown',
    'focus .js-button': function () {
      this.trigger('focus', this);
    },
    'blur': function () {
      this.trigger('blur', this);
    }
  },

  options: {
    selectedItemTemplate: selectedItemTemplate
  },

  initialize: function (opts) {
    Backbone.Form.editors.Base.prototype.initialize.call(this, opts);
    this._setOptions(opts);

    this.template = opts.template || template;
    this.dialogMode = this.options.dialogMode || 'nested';

    var collectionOptions = {
      configModel: this.options.configModel,
      layerDefinitionModel: this.options.layerDefinitionModel,
      country: this.model.get('country') || null
    };

    this.measurementsCollection = new MeasurementsCollection([], collectionOptions);
    this.filtersCollection = new FiltersCollection([], collectionOptions);

    this._modelView = new Backbone.Model({
      state: STATE.idle
    });

    this._initBinds();

    this._dialogView = new DropdownDialogView({
      measurementsCollection: this.measurementsCollection,
      filtersCollection: this.filtersCollection
    });

    this._fetch();
  },

  render: function () {
    var isLoading = this._isLoading();
    var isEmpty = !this._hasItems();
    var isDisabled = !isEmpty ? this.options.disabled : true;
    var name = this.model.get(this.options.keyAttr);
    var item = this.measurementsCollection.getItem(name);
    var isNull = name === null;
    var label = isNull ? 'null' : (item ? item.get('name') : false);
    var placeholder = this.options.placeholder;

    this.$el.html(
      this.template({
        label: label,
        keyAttr: this.options.keyAttr,
        placeholder: placeholder,
        isDisabled: isDisabled,
        isLoading: isLoading,
        isEmpty: isEmpty,
        isNull: isNull
      })
    );

    this._popupManager = new PopupManager(this.cid, this.$el, this._dialogView.$el);
    this._popupManager.append(this.dialogMode);

    return this;
  },

  _initBinds: function () {
    var hide = function () {
      this._dialogView.hide();
      this._popupManager.untrack();
    }.bind(this);

    this.applyESCBind(hide);
    this.applyClickOutsideBind(hide);

    this.listenTo(this.measurementsCollection, 'change:selected', this._onItemSelected);
    this.listenTo(this._modelView, 'change:state', this.render);
    this.listenTo(this.model, 'change:country', this._fetch);
  },

  _fetch: function () {
    var fetchOptions = {
      success: this._onFetchSuccess.bind(this),
      error: this._onFetchError.bind(this)
    };

    this.measurementsCollection.fetch(fetchOptions);
    this.filtersCollection.fetch(fetchOptions);
    this._modelView.set({state: STATE.loading});

    this.setValue(this.model.get(this.options.keyAttr));
  },

  _onFetchSuccess: function () {
    var measurementsReady = this.measurementsCollection.getState() === STATE.fetched;
    var filtersReady = this.filtersCollection.getState() === STATE.fetched;

    if (filtersReady && measurementsReady) {
      this._modelView.set({state: STATE.fetched});
    }
  },

  _onFetchError: function () {
    this._modelView.set({state: STATE.error});
  },

  _hasItems: function () {
    var state = this.measurementsCollection.getState();
    return state === STATE.fetched && this.measurementsCollection.filter(function (mdl) {
      var filter = mdl.get('filter');
      return filter.length > 0;
    }).length > 0;
  },

  _isLoading: function () {
    var state = this.measurementsCollection.getState();
    return state === STATE.fetching;
  },

  _onItemSelected: function (mdl) {
    this._dialogView.hide();
    this._popupManager.untrack();
    this._renderButton(mdl).focus();
    this.trigger('change', this);
  },

  _onButtonClick: function () {
    if (this._hasItems()) {
      this._dialogView.toggle();
      this._dialogView.isVisible() ? this._popupManager.track() : this._popupManager.untrack();
    }
  },

  _onButtonKeyDown: function (ev) {
    if (ev.which === ENTER_KEY_CODE) {
      ev.preventDefault();
      if (!this._dialogView.isVisible()) {
        ev.stopPropagation();
        this._onButtonClick();
      } else {
        this._popupManager.track();
      }
    }
  },

  getValue: function () {
    var item = this.measurementsCollection.getSelectedItem();
    if (item) {
      return item.getName();
    }
    return;
  },

  setValue: function (value) {
    var selectedModel = this.measurementsCollection.setSelected(value);
    if (selectedModel) {
      this._renderButton(selectedModel);
    }
    this.value = value;
  },

  _renderButton: function (mdl) {
    var button = this.$('.js-button');
    var $html = this.options.selectedItemTemplate({
      label: mdl.getName()
    });

    button
      .removeClass('is-empty')
      .html($html);

    return button;
  },

  remove: function () {
    this._popupManager && this._popupManager.destroy();
    this._dialogView && this._dialogView.clean();
    Backbone.Form.editors.Base.prototype.remove.call(this);
  }

});
