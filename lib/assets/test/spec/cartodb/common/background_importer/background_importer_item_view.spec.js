var cdb = require('cartodb.js');
var ImportsModel = require('../../../../../javascripts/cartodb/common/background_importer/imports_model');
var BackgroundImporterItemView = require('../../../../../javascripts/cartodb/common/background_importer/background_importer_item_view');

describe('common/background_importer/background_importer_item_view', function() {

  beforeEach(function() {
    var user = new cdb.admin.User({
      base_url: 'http://paco.cartodb.com',
      username: 'paco'
    });
    this.model = new ImportsModel();

    spyOn(this.model, 'bind').and.callThrough();

    this.view = new BackgroundImporterItemView({
      createVis: false,
      model: this.model,
      user: user
    });
  });

  it('should render properly', function() {
    this.view.render();
    expect(this.view.$el.hasClass('ImportItem')).toBeTruthy();
    expect(this.view.$('.ImportItem-text').length).toBe(1);
  });

  it('should bind model changes', function() {
    expect(this.model.bind.calls.argsFor(0)[0]).toEqual('change:state');
    expect(this.model.bind.calls.argsFor(1)[0]).toEqual('change');
    expect(this.model.bind.calls.argsFor(2)[0]).toEqual('remove');
  });

  it('should stop upload and remove it when upload is aborted', function() {
    this.view.render();
    spyOn(this.view, 'clean');
    this.model.set('state', 'uploading');
    this.view.$('.js-abort').click();
    expect(this.view.clean).toHaveBeenCalled();
  });

  it('should have no leaks', function() {
    this.view.render();
    expect(this.view).toHaveNoLeaks();
  });

  afterEach(function() {
    this.view.clean();
  });

});
