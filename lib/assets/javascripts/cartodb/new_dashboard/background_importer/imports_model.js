var cdb = require('cartodb.js');
var ImportModel = require('../../new_dashboard/background_importer/import_model');
var UploadModel = require('../../new_common/upload_model');

/** 
 *  Upload/import model
 *  
 *  It takes the control of the upload and import, 
 *  listening the change of any of these steps.
 *
 *  Steps:
 *  - upload
 *  - import
 *
 */

module.exports = cdb.core.Model.extend({

  defaults: {
    step: 'upload',
    state: ''
  },

  initialize: function(val, opts) {
    if (_.isEmpty(val)) val = {};
    this.user = opts && opts.user;
    this.upl = new UploadModel(val.upload, { user: this.user });
    this.imp = new ImportModel(val.import);
    this._initBinds();
    this._checkStatus();
  },

  _initBinds: function() {
    this.bind('change:import',  this._onImportChange, this);
    this.bind('change:upload',  this._onUploadChange, this);
    this.bind('change:id',      this._onIdChange, this);

    this.imp.bind('change', function() {
      this.trigger('change:import');
      this.trigger('change');
    }, this);
    this.upl.bind('change', function() {
      this.trigger('change:upload');
      this.trigger('change');
    }, this)
  },

  _destroyBinds: function() {
    this.upl.unbind(null, null, this);
    this.imp.unbind(null, null, this); 
  },

  _onIdChange: function() {
    var item_queue_id = this.get('id');
    if (item_queue_id) this.imp.set('item_queue_id', item_queue_id);
    this.set('step', 'import');
  },

  _onUploadChange: function(m, i) {
    if (this.get('step') === "upload") {
      var item_queue_id = this.upl.get('item_queue_id');
      var state = this.upl.get('state');
      
      if (item_queue_id) this.set('id', item_queue_id);
      if (state) this.set('state', state);
    }
  },

  _onImportChange: function() {
    if (this.get('step') === "import") {
      var state = this.imp.get('state');
      if (state) this.set('state', state);
    }
  },

  _checkStatus: function() {
    if (this.upl.get('type') === 'file') {
      this.upl.upload();
    } else if (this.get('id')) {
      this.set('step', 'import');
      this.imp.set('item_queue_id', this.get('id'));
    } else if (!this.imp.get('item_queue_id') && this.upl.get('type') !== "") {
      if (this.upl.isValid()) {
        this.set('step', 'import');
        this.imp.createImport(this.upl.toJSON());
      } else {
        // Upload is invalid so we need
        // checking init attributes
        this.trigger('change:upload');
      }
    }
  },

  pause: function() {
    this.stopUpload();
    this.stopImport();
  },

  hasFailed: function() {
    var state = this.get('state');
    var step = this.get('step');

    if (( state === "failure" && step === "import" ) || ( state === "error" && step === "upload" )) {
      return true;
    }
    return false;
  },

  hasCompleted: function() {
    return this.get('step') === "import" && this.imp && this.imp.get('state') === 'complete'
  },

  getError: function() {
    if (this.hasFailed()) {
      var step = this.get('step');
      return _.extend(
        {
          error_code: this[step === "upload" ? 'upl' : 'imp'].get('error_code'),
          item_queue_id: step === "import" ? this.imp.get('id') : ''
        }
        ,
        this[step === "upload" ? 'upl' : 'imp'].get('get_error_text')
      )
    }

    return {
      title: '',
      what_about: '',
      error_code: ''
    }
  },

  getVisMetadata: function() {
    var derivedVisId = this.imp.get('derived_visualization_id');

    if (!derivedVisId) {
      return false;
    }

    var vis = new cdb.admin.Visualization({ id: derivedVisId });
    vis.permission.owner = this.user;

    return vis;
  },

  getTableMetadata: function() {
    var tableName = this.imp.get('table_name');

    if (!tableName) {
      return false;
    }

    return new cdb.admin.CartoDBTableMetadata({ name: tableName });
  },

  stopUpload: function() {
    this.upl.stopUpload();
  },

  stopImport: function() {
    this.imp.destroyCheck();
  },

  get: function (attr) {
    if (attr === "upload") return this.upl.toJSON();
    if (attr === "import") return this.imp.toJSON();

    return cdb.core.Model.prototype.get.call(this, attr);
  },

  toJSON: function() {
    return {
      step: this.get('step'),
      id: this.get('id'),
      state: this.get('state'),
      upload: this.upl.toJSON(),
      import: this.imp.toJSON()
    }
  }

});