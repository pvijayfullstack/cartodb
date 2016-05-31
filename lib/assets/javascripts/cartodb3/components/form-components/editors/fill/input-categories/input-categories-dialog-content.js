var _ = require('underscore');
var Backbone = require('backbone');
var cdb = require('cartodb.js');
var InputColorPickerView = require('../input-color/input-color-picker-view');
var CategoriesListView = require('./categories-list-view');
var ColumnListView = require('../column-list-view');
var StackLayoutView = require('../../../../../components/stack-layout/stack-layout-view');
var QuerySchemaModel = require('../../../../../data/query-schema-model');

var DEFAULT_COLORS = ['#A6CEE3', '#1F78B4', '#B2DF8A', '#33A02C', '#FB9A99', '#E31A1C', '#FDBF6F', '#FF7F00', '#CAB2D6', '#6A3D9A', '#DDDDDD'];
var MAX_VALUES = 9;

module.exports = cdb.core.View.extend({
  initialize: function (opts) {
    if (!opts.columns) throw new Error('columns param is required');
    if (!opts.configModel) throw new Error('configModel param is required');
    if (!opts.query) throw new Error('query param is required');

    this._columns = opts.columns;
    this._configModel = opts.configModel;
    this._query = opts.query;

    this._initBinds();
    this._initViews();
  },

  render: function () {
    this.clearSubViews();
    this.$el.empty();

    this.$el.append(this._stackLayoutView.render().$el);
    return this;
  },

  _initBinds: function () {
    this.model.on('change:attribute', this._fetchColumns, this);
  },

  _initViews: function () {
    var self = this;

    var stackViewCollection = new Backbone.Collection([{
      createStackView: function (stackLayoutModel, opts) {
        return self._createColumnListView(stackLayoutModel, opts).bind(self);
      }
    }, {
      createStackView: function (stackLayoutModel, opts) {
        return self._createRampListView(stackLayoutModel, opts).bind(self);
      }
    }, {
      createStackView: function (stackLayoutModel, opts) {
        return self._createColorPickerView(stackLayoutModel, opts).bind(self);
      }
    }]);

    this._stackLayoutView = new StackLayoutView({
      collection: stackViewCollection
    });

    if (this.model.get('attribute')) {
      this._stackLayoutView.model.set('position', 1);
    }
  },

  _fetchColumns: function () {
    this._querySchemaModel = new QuerySchemaModel(null, {
      configModel: this._configModel
    });

    var tmpl = _.template('SELECT <%= column %>, count(<%= column %>) FROM (<%= sql %>) _table_sql GROUP BY <%= column %> ORDER BY count DESC LIMIT <%= max_values %> ');

    this._querySchemaModel.set('query', tmpl({
      sql: this._query,
      column: this.model.get('attribute'),
      max_values: MAX_VALUES + 1
    }));

    this._querySchemaModel.on('change:status', this._onStatusChange, this);
    this._querySchemaModel.fetch();
  },

  _onStatusChange: function () {
    if (this._querySchemaModel.get('status') === 'fetching') {
      return;
    }
    var names = this._querySchemaModel.rowsSampleCollection.pluck(this.model.get('attribute'));

    var ramp = this.model.get('ramp');

    ramp = _.map(names, function (name, i) {
      return (ramp.length < i) ? DEFAULT_COLORS[i] : ramp[i];
    });

    var domain = _.map(names, function (name, i) {
      return name;
    }).sort();

    if (names.length > MAX_VALUES) {
      domain.push('Others');
      ramp.push(DEFAULT_COLORS[names.length]);
    }

    this.model.set({
      ramp: ramp,
      domain: domain
    });
  },

  _updateRamp: function (categories) {
    var ramp = this.model.get('ramp');
    ramp[this._index] = categories[this._index].color;
    this.model.set('ramp', ramp);
    this.model.trigger('change:ramp', ramp);
    this.trigger('change', ramp, this);
  },

  _createColorPickerView: function (stackLayoutModel, opts) {
    var ramp = _.map(this.model.get('ramp'), function (color, i) {
      return { val: color, color: color, title: this.model.get('domain')[i] };
    }, this);

    var view = new InputColorPickerView({
      index: this._index,
      ramp: ramp
    });

    view.bind('back', function (value) {
      stackLayoutModel.prevStep();
    }, this);

    view.bind('change', this._updateRamp, this);
    view.bind('changeIndex', function (index) {
      this._index = index;
    }, this);

    return view;
  },

  _createColumnListView: function (stackLayoutModel, opts) {
    var stringColumns = _.filter(this._columns, function (column) {
      return column.type === 'string';
    }, this);

    var view = new ColumnListView({
      stackLayoutModel: stackLayoutModel,
      columns: stringColumns,
      showSearch: true,
      typeLabel: 'column'
    });

    view.bind('selectItem', function (value) {
      this.model.set('attribute', value);
      stackLayoutModel.nextStep();
    }, this);

    return view;
  },

  _createRampListView: function (stackLayoutModel, opts) {
    var view = new CategoriesListView({
      model: this.model
    });

    view.bind('back', function (value) {
      stackLayoutModel.prevStep();
    }, this);

    view.bind('selectItem', function (index) {
      this._index = index;
      stackLayoutModel.nextStep();
    }, this);

    return view;
  }
});
