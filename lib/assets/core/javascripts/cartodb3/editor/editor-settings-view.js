var CoreView = require('backbone/core-view');
var OptionsView = require('./settings/preview/preview-view');
var ScrollView = require('../components/scroll/scroll-view');
var Header = require('./editor-header.js');
var PublishView = require('../components/modals/publish/publish-view');
var ShareButtonView = require('./layers/share-button-view');
var PanelWithOptionsView = require('../components/view-options/panel-with-options-view');
var checkAndBuildOpts = require('../helpers/required-opts');

var REQUIRED_OPTS = [
  'modals',
  'visDefinitionModel',
  'privacyCollection',
  'mapDefinitionModel',
  'mapcapsCollection',
  'overlaysCollection',
  'editorModel',
  'settingsCollection',
  'configModel',
  'userModel'
];

module.exports = CoreView.extend({
  className: 'Editor-panel',
  initialize: function (opts) {
    checkAndBuildOpts(opts, REQUIRED_OPTS, this);
    this._editorModel.set('edition', false);
  },

  render: function () {
    this.clearSubViews();
    this.$el.empty();

    var header = new Header({
      userModel: this._userModel,
      editorModel: this._editorModel,
      configModel: this._configModel,
      mapcapsCollection: this._mapcapsCollection,
      modals: this._modals,
      visDefinitionModel: this._visDefinitionModel,
      privacyCollection: this._privacyCollection,
      onClickPrivacy: this._share.bind(this),
      onRemoveMap: this._onRemoveMap.bind(this)
    });

    this.$el.append(header.render().$el);
    this.addView(header);

    var view = new PanelWithOptionsView({
      className: 'Editor-content',
      editorModel: this._editorModel,
      createContentView: function () {
        return new ScrollView({
          createContentView: function () {
            return new OptionsView({
              mapDefinitionModel: this._mapDefinitionModel,
              settingsCollection: this._settingsCollection,
              overlaysCollection: this._overlaysCollection
            });
          }.bind(this)
        });
      }.bind(this),
      createActionView: function () {
        return new ShareButtonView({
          visDefinitionModel: this._visDefinitionModel,
          onClickAction: this._share.bind(this)
        });
      }.bind(this)
    });

    this.$el.append(view.render().$el);
    this.addView(view);

    return this;
  },

  _share: function () {
    this._modals.create(function (modalModel) {
      return new PublishView({
        mapcapsCollection: this._mapcapsCollection,
        modalModel: modalModel,
        visDefinitionModel: this._visDefinitionModel,
        privacyCollection: this._privacyCollection,
        userModel: this._userModel,
        configModel: this._configModel
      });
    }.bind(this));
  },

  _onRemoveMap: function () {
    window.location = this._userModel.get('base_url');
  }
});
