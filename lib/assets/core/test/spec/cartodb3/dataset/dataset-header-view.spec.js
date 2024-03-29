var _ = require('underscore');
var ConfigModel = require('../../../../javascripts/cartodb3/data/config-model');
var HeaderView = require('../../../../javascripts/cartodb3/dataset/dataset-header/dataset-header-view');
var UserModel = require('../../../../javascripts/cartodb3/data/user-model');
var AnalysisDefinitionNodeSourceModel = require('../../../../javascripts/cartodb3/data/analysis-definition-node-source-model');
var VisModel = require('../../../../javascripts/cartodb3/data/vis-definition-model');
var LayerDefinitionModel = require('../../../../javascripts/cartodb3/data/layer-definition-model');

describe('dataset/dataset-header-view', function () {
  beforeEach(function () {
    jasmine.Ajax.install();
    jasmine.Ajax.stubRequest(new RegExp('^http(s)?.*map.*'))
      .andReturn({ status: 200 });

    var configModel = new ConfigModel({
      base_url: '/u/pepe'
    });

    var layerModel = new LayerDefinitionModel({
      id: 'harr',
      type: 'CartoDB',
      options: {
        sql: 'SELECT * FROM table_1',
        table_name: 'table_1',
        cartocss: '...',
        source: 'd1'
      },
      url: '/u/pepe/api/v1/maps/2222/layers/11111'
    }, {
      configModel: configModel,
      stateDefinitionModel: {}
    });

    spyOn(layerModel, 'sync').and.callThrough(function (a, b, opts) {
      opts && opts.success();
    });

    layerModel.url = function () {
      var baseUrl = configModel.get('base_url');
      return baseUrl + '/api/v1/maps/2222/layers/11111';
    };

    var userModel = new UserModel({
      username: 'pepe',
      actions: {
        private_tables: true
      }
    }, {
      configModel: configModel
    });

    this.analysisDefinitionNodeModel = new AnalysisDefinitionNodeSourceModel({
      query: 'select * from table_1',
      table_name: 'table_1',
      id: 'dummy-id'
    }, {
      tableData: {
        name: 'table_1',
        permission: {
          owner: {
            username: 'pepe'
          }
        },
        synchronization: {}
      },
      configModel: configModel,
      userModel: userModel
    });

    this.querySchemaModel = this.analysisDefinitionNodeModel.querySchemaModel;
    this.queryGeometryModel = this.analysisDefinitionNodeModel.queryGeometryModel;
    this.tableModel = this.analysisDefinitionNodeModel.getTableModel();
    this.syncModel = this.tableModel.getSyncModel();

    spyOn(this.querySchemaModel, 'fetch');
    spyOn(this.queryGeometryModel, 'fetch');
    spyOn(this.tableModel, 'isSync');
    spyOn(this.syncModel, 'isSync');
    spyOn(this.tableModel, 'isOwner').and.returnValue(true);

    var visModel = new VisModel({
      name: 'table_1',
      privacy: 'PUBLIC',
      permission: {}
    }, {
      configModel: configModel
    });

    var router = jasmine.createSpyObj('router', ['navigate']);
    var modals = jasmine.createSpyObj('modals', ['create']);

    spyOn(HeaderView.prototype, 'render').and.callThrough();
    spyOn(HeaderView.prototype, '_setDocumentTitle');
    this.view = new HeaderView({
      modals: modals,
      router: router,
      configModel: configModel,
      userModel: userModel,
      visModel: visModel,
      analysisDefinitionNodeModel: this.analysisDefinitionNodeModel,
      layerDefinitionModel: layerModel
    }, {
      configModel: this._configModel
    });

    this.view.render();
  });

  afterEach(function () {
    jasmine.Ajax.uninstall();
  });

  describe('render', function () {
    it('should render the inline editor view', function () {
      spyOn(this.view._userModel, 'isInsideOrg').and.returnValue(true);
      this.tableModel.isSync.and.returnValue(false);
      this.view._tableModel.isOwner.and.returnValue(true);
      expect(_.size(this.view._subviews)).toBe(2);
      expect(this.view.$('.Inline-editor').length).toBe(1);
      expect(this.view.$('.SyncInfo-state').length).toBe(0);
    });

    it('should not render the inline editor view but sync table info', function () {
      spyOn(this.view._userModel, 'isInsideOrg').and.returnValue(true);
      this.tableModel.isSync.and.returnValue(true);
      this.view._tableModel.isOwner.and.returnValue(true);
      this.view.render();
      expect(_.size(this.view._subviews)).toBe(2); // inline editor, with bagde
      expect(this.view.$('.Inline-editor').length).toBe(0);
      expect(this.view.$('.SyncInfo-state').length).toBe(1);
    });

    it('should not render the inline editor or the sync info view or the share info view if owner is different', function () {
      spyOn(this.view._userModel, 'isInsideOrg').and.returnValue(true);
      this.view._tableModel.isOwner.and.returnValue(false);
      this.tableModel.isSync.and.returnValue(true);
      this.view.render();
      expect(_.size(this.view._subviews)).toBe(0);
      expect(this.view.$('.Inline-editor').length).toBe(0);
      expect(this.view.$('.SyncInfo-state').length).toBe(0);
    });

    it('should render privacy dropdown when user doesn\'t belong to an organization', function () {
      spyOn(this.view._userModel, 'isInsideOrg').and.returnValue(false);
      this.tableModel.isSync.and.returnValue(false);
      this.view._tableModel.isOwner.and.returnValue(true);
      this.view.render();
      expect(_.size(this.view._subviews)).toBe(2);
      expect(this.view.$('.Inline-editor').length).toBe(1);
      expect(this.view.$('.SyncInfo-state').length).toBe(0);
      expect(this.view.$('.js-dialog').length).toBe(1);
    });

    it('should render read permission tag if user can only read the dataset', function () {
      spyOn(this.view._tableModel._permissionModel, 'isOwner').and.returnValue(false);
      spyOn(this.view._tableModel._permissionModel, 'hasWriteAccess').and.returnValue(false);
      this.view.render();

      expect(this.view.$('.js-readPermissionTag').length).toBe(1);
    });
  });

  describe('binds', function () {
    it('should change table name when vis name changes', function () {
      spyOn(this.analysisDefinitionNodeModel, 'setTableName').and.callThrough();
      expect(this.tableModel.get('name')).toBe('table_1');
      this.view._visModel.set('name', 'hello_new_table');
      expect(this.analysisDefinitionNodeModel.setTableName).toHaveBeenCalledWith('hello_new_table');
      expect(this.tableModel.get('name')).toBe('hello_new_table');
    });

    it('should render when privacy or name changes', function () {
      HeaderView.prototype.render.calls.reset();
      this.view._visModel.set('name', 'hello_new_table');
      expect(HeaderView.prototype.render).toHaveBeenCalled();
    });

    it('should set document title when vis name changes', function () {
      HeaderView.prototype._setDocumentTitle.calls.reset();
      this.view._visModel.set('name', 'hello_new_table');
      expect(HeaderView.prototype._setDocumentTitle).toHaveBeenCalled();
    });

    it('should change router url when vis name changes', function () {
      this.view._visModel.set('name', 'hello_new_table');
      expect(this.view._router.navigate).toHaveBeenCalled();
    });

    it('should set default query when vis name changes', function () {
      HeaderView.prototype._setDocumentTitle.calls.reset();
      this.view._visModel.set('name', 'hello_new_table');
      expect(this.view._layerDefinitionModel.get('sql')).toBe('SELECT * FROM hello_new_table');
    });

    it('should open privacy dialog link if user is owner and it belongs to an organization', function () {
      spyOn(this.view._userModel, 'isInsideOrg').and.returnValue(true);
      this.view._tableModel.isOwner.and.returnValue(true);
      this.view.render();
      this.view.$('.js-privacy').click();
      expect(this.view._modals.create).toHaveBeenCalled();
    });

    it('should not open privacy link if user is not owner', function () {
      this.view._tableModel.isOwner.and.returnValue(false);
      this.view.render();
      this.view.$('.js-privacy').click();
      expect(this.view._modals.create).not.toHaveBeenCalled();
    });

    it('should render when synchronization has been destroyed', function () {
      HeaderView.prototype.render.calls.reset();
      this.syncModel.destroy();
      expect(HeaderView.prototype.render).toHaveBeenCalled();
    });
  });

  it('should not have leaks', function () {
    expect(this.view).toHaveNoLeaks();
  });

  afterEach(function () {
    this.view.clean();
  });
});
