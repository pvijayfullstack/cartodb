var $ = require('jquery');
var _ = require('underscore');
var cdb = require('cartodb.js');
var CustomListView = require('../custom-list/custom-list-view');
var CustomListItemView = require('../custom-list/custom-list-item-view');
var itemTemplate = require('../custom-list/custom-list-item.tpl');

/*
 *  A context menu
 */
module.exports = cdb.core.View.extend({

  options: {
    offset: {},
    itemTemplate: itemTemplate,
    itemView: CustomListItemView
  },

  className: 'CDB-Box-modal CDB-SelectItem CustomList--small',
  tagName: 'div',

  initialize: function (opts) {
    _.bindAll(this, '_onEscapePressed', '_onDocumentElementClicked');

    opts = opts || {};
    if (!opts.collection) {
      throw new Error('collection option is required');
    }

    if (!opts.triggerElementID) {
      throw new Error('triggerElementID option is required');
    }

    this.options = _.extend({}, this.options, opts);

    this.model = new cdb.core.Model({
      visible: false
    });

    this._initBinds();

    $(document).bind('keydown', this._onEscapePressed);
    $(document).bind('click', this._onDocumentElementClicked);
  },

  _onEscapePressed: function (ev) {
    if (ev.which === $.ui.keyCode.ESCAPE) {
      this.hide();
    }
  },

  _onDocumentElementClicked: function (e) {
    var clickedElement = e.target;
    var triggerElement = $('#' + this.options.triggerElementID)[0];
    if (triggerElement === clickedElement || $.contains(triggerElement, clickedElement)) {
      this.toggle();
    } else {
      this.hide();
    }
  },

  clean: function () {
    $(document).unbind('keydown', this._onEscapePressed);
    $(document).unbind('click', this._onDocumentElementClicked);

    cdb.core.View.prototype.clean.apply(this);
  },

  _initBinds: function () {
    this.model.on('change:visible', this.render, this);
    this.collection.on('change:selected', this.hide, this);
  },

  render: function () {
    this.$el.empty();
    this.clearSubViews();
    this._renderList();

    if (this.options.offset) {
      _.each(['top', 'right', 'bottom', 'left'], function (attr) {
        var val = this.options.offset[attr];
        if (val) {
          this.$el.css(attr, val);
        }
      }, this);
    }

    this.$el.toggle(this.isVisible());

    return this;
  },

  _renderList: function () {
    var listView = new CustomListView({
      model: this.model,
      collection: this.collection,
      typeLabel: '',
      ItemView: this.options.itemView,
      itemTemplate: this.options.itemTemplate
    });
    this.$el.append(listView.render().el);
    this.addView(listView);
  },

  show: function () {
    this.model.set('visible', true);
  },

  hide: function () {
    this.model.set('visible', false);
  },

  toggle: function () {
    this.model.set('visible', !this.model.get('visible'));
  },

  isVisible: function () {
    return this.model.get('visible');
  }
});
