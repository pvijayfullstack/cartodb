var cdb = require('cartodb.js');
var UploadConfig = require('../../config/upload-config');
var ErrorDetailsView = require('./error-details-view');
var WarningsDetailsView = require('./warnings-details-view');
var TwitterImportDetailsDialog = require('./twitter-import-details-view');
var template = require('./background-import-item.tpl');

/**
 *  Import item within background importer
 *
 */

module.exports = cdb.core.View.extend({

  className: 'ImportItem',
  tagName: 'li',

  events: {
    'click .js-abort': '_removeItem',
    'click .js-show_error': '_showImportError',
    'click .js-show_warnings': '_showImportWarnings',
    'click .js-show_stats': '_showImportStats',
    'click .js-close': '_removeItem'
  },

  initialize: function (opts) {
    if (!opts.userModel) throw new Error('userModel is required');
    if (!opts.configModel) throw new Error('configModel is required');
    if (!opts.modals) throw new Error('modals is required');

    this._userModel = opts.userModel;
    this._configModel = opts.configModel;
    this._modals = opts.modals;

    this._initBinds();
  },

  render: function () {
    var upload = this.model.get('upload');
    var imp = this.model.get('import');

    var d = {
      name: '',
      state: this.model.get('state'),
      progress: '',
      service: '',
      step: this.model.get('step'),
      url: '',
      failed: this.model.hasFailed(),
      completed: this.model.hasCompleted(),
      warnings: this.model.getWarnings(),
      showSuccessDetailsButton: this._showSuccessDetailsButton,
      tables_created_count: imp.tables_created_count
    };

    // Name
    if (upload.type) {
      if (upload.type === 'file') {
        if (upload.value.length > 1) {
          d.name = upload.value.length + ' files';
        } else {
          d.name = upload.value.name;
        }
      }
      if (upload.type === 'url' || upload.type === 'remote') {
        d.name = upload.value;
      }
      if (upload.type === 'service') {
        d.name = upload.value && upload.value.filename || '';
      }
      if (upload.service_name === 'twitter_search') {
        d.name = 'Twitter import';
      }
      if (upload.type === 'sql') {
        d.name = 'SQL';
      }
      if (upload.type === 'duplication') {
        d.name = upload.table_name || upload.value;
      }
    } else {
      d.name = imp.display_name || imp.item_queue_id || 'import';
    }

    // Service
    d.service = upload.service_name;

    // Progress
    if (this.model.get('step') === 'upload') {
      d.progress = this.model.get('upload').progress;
    } else {
      d.progress = (UploadConfig.uploadStates.indexOf(d.state) / UploadConfig.uploadStates.length) * 100;
    }

    this.$el.html(template(d));

    return this;
  },

  _initBinds: function () {
    this.model.bind('change', this.render, this);
    this.model.bind('remove', this.clean, this);
  },

  _removeItem: function () {
    this.trigger('remove', this.model, this);
    this.model.pause();
    this.clean();
  },

  _showImportStats: function () {
    var self = this;
    var modal = this._modals.create(function (modalModel) {
      return new TwitterImportDetailsDialog({
        modalModel: modalModel,
        userModel: self._userModel,
        model: self.model
      });
    });
    modal.show();
  },

  _showImportError: function () {
    var self = this;

    var modal = this._modals.create(function (modalModel) {
      return new ErrorDetailsView({
        configModel: self._configModel,
        modalModel: modalModel,
        error: self.model.getError(),
        userModel: self._userModel
      });
    });
    modal.show();
  },

  _showImportWarnings: function () {
    var self = this;

    var modal = this._modals.create(function (modalModel) {
      return new WarningsDetailsView({
        modalModel: modalModel,
        warnings: self.model.getWarnings(),
        userModel: self._userModel
      });
    });
    modal.show();
  }
});
