var ItemView = require('new_dashboard/datasets/datasets_item');
var Router = require('new_dashboard/router');

describe('new_dashboard/datasets/datasets_item', function() {
  beforeEach(function() {
    spyOn(cdb.config, 'prefixUrl');
    cdb.config.prefixUrl.and.returnValue('/u/pepe');

    this.tablemetadata = {
      row_count:      9000,
      size:           1000,
      geometry_types: ['st_point']
    };

    this.vis = new cdb.admin.Visualization({
      name: 'my_dataset',
      privacy: 'PRIVATE',
      updated_at: (new Date()).toISOString(),
      likes: 42,
      table: this.tablemetadata
    });

    spyOn(this.vis, 'on');

    this.user = new cdb.admin.User({});

    this.router = new Router({
      rootUrl: ''
    });
    this.router.model.set('content_type', 'datasets');

    this.view = new ItemView({
      model: this.vis,
      user: this.user,
      router: this.router
    });


    this.html = 'call this.renderView(); in your test case!';
    this.renderView = function() {
      this.view.render();
      this.html = this.view.el.innerHTML;
    };
  });

  it('should have no leaks', function() {
    this.renderView();
    expect(this.view).toHaveNoLeaks();
  });

  it('should render if dataset changes', function() {
    expect(this.vis.on).toHaveBeenCalledWith('change', this.view.render, this.view);
  });

  it('should render the title', function() {
    this.renderView();
    expect(this.html).toContain('my_dataset');
  });

  it('should render the URL to dataset', function() {
    this.renderView();
    // TODO: need to be updated once we have the new dataset page
    expect(this.html).toContain('/u/pepe/tables/my_dataset');
  });

  it('should render likes count', function() {
    this.renderView();
    expect(this.html).toContain('42');
  });

  it('should render row count', function() {
    this.renderView();
    expect(this.html).toContain('9,000 Rows');
  });

  it('should render table size', function() {
    this.renderView();
    expect($(this.html).find('.SizeIndicator').length).toBe(1);
    expect($(this.html).find('.SizeIndicator').text()).toContain('1000 bytes');
  });

  it('should render table geometry type', function() {
    this.renderView();
    expect(this.view.$('.DatasetsList-itemCategory').length).toBe(1);
    expect(this.view.$('.DatasetsList-itemCategory').hasClass('is--pointDataset')).toBeTruthy();
  });

  it('should render raster icon when dataset is raster', function() {
    this.vis.set('kind', 'raster');
    this.renderView();
    expect(this.view.$('.DatasetsList-itemCategory').length).toBe(1);
    expect(this.view.$('.DatasetsList-itemCategory').hasClass('is--pointDataset')).toBeFalsy();
    expect(this.view.$('.DatasetsList-itemCategory').hasClass('is--rasterDataset')).toBeTruthy();
  });

  it('should render privacy', function() {
    this.renderView();
    expect(this.html).toContain('private');
  });

  it('should render timediff', function() {
    this.renderView();
    expect(this.html).toContain('a few seconds ago');
  });

  describe('given visualization is of kind raster', function() {
    beforeEach(function() {
      this.vis.set('kind', 'raster');
    });

    it('should title as a non-link disabled item', function() {
      this.renderView();
      expect(this.html).not.toContain('/u/pepe/tables/my_dataset');
    });
  });

  describe('given row_count is not set', function() {
    beforeEach(function() {
      this.view.table.unset('row_count');
    });

    it('should not render row count', function() {
      this.renderView();
      expect(this.html).not.toContain('Rows');
    });
  });

  describe('given dataset is selected', function() {
    beforeEach(function() {
      this.vis.set('selected');
      this.renderView();
      expect(this.html).toContain('DatasetsItem is--selected');
    });
  });

  describe('given description is set', function() {
    beforeEach(function() {
      this.vis.set('description', 'my desc');
    });

    it('should show description', function() {
      this.renderView();
      expect(this.html).toContain('my desc');
    });

    it('should not show link to add a description', function() {
      this.renderView();
      expect(this.html).not.toContain('Add a description...');
    });
  });

  describe('given description is not set', function() {
    it('should show link to add a description', function() {
      this.renderView();
      expect(this.html).toContain('Add a description...');

      // Empty string too
      this.vis.set('description', '');
      this.renderView();
      expect(this.html).toContain('Add a description...');
    });
  });

  describe('given user owns dataset', function() {
    beforeEach(function() {
      spyOn(this.vis.permission, 'isOwner').and.returnValue(true);
    });

    it('should not render permission indicator', function() {
      this.renderView();
      expect(this.html).not.toContain('PermissionIndicator');
      expect(this.html).not.toContain('READ');
    });

    it('should not render user avatar', function() {
      expect(this.html).not.toContain('UserAvatar');
    });
  });

  describe('given user does NOT own dataset', function() {
    beforeEach(function() {
      spyOn(this.vis.permission, 'isOwner').and.returnValue(false);
    });

    it('should render user avatar', function() {
      this.renderView();
      expect(this.html).toContain('UserAvatar');
    });

    describe('and permission is set to read only', function() {
      beforeEach(function() {
        spyOn(this.vis.permission, 'getPermission').and.returnValue(cdb.admin.Permission.READ_ONLY);
      });

      it('should render permission indicator', function() {
        this.renderView();
        expect(this.vis.permission.getPermission).toHaveBeenCalledWith(this.user);
        expect(this.html).toContain('READ');
        expect(this.html).toContain('PermissionIndicator');
      });
    });
  });

  describe('given there are no tags', function() {
    it('should render a link to add tags', function() {
      this.renderView();
      expect(this.html).toContain('Add tags...');
    });
  });

  describe('given there are at least one tag', function() {
    beforeEach(function() {
      this.vis.set('tags', ['ole', 'dole', 'doff', 'kinke', 'lane', 'koff']);
    });

    it('should only render first three', function() {
      this.renderView();
      expect(this.html).toContain('ole');
      expect(this.html).toContain('dole');
      expect(this.html).toContain('doff');
      expect(this.html).not.toContain('kinke');
      expect(this.html).not.toContain('lane');
      expect(this.html).not.toContain('koff');
    });

    it('should render a text of how many tags remain', function() {
      this.renderView();
      expect(this.html).toContain('and 3 more');
    });

    it('each tag should have a URL to the tag', function() {
      this.renderView();
      expect(this.html).toContain('tag/ole');
      expect(this.html).toContain('tag/dole');
      expect(this.html).toContain('tag/doff');
    });
  });

  describe('click item', function() {
    describe('given clicked target is NOT a link', function() {
      beforeEach(function() {
        spyOn(this.view, 'killEvent');
        this.renderView();
        this.clickEl = function() {
          this.view.$el.click();
        };
        this.clickEl();
      });

      it('should kill default event behaviour', function() {
        expect(this.view.killEvent).toHaveBeenCalledWith(this.view.killEvent.calls.argsFor(0)[0]);
      });

      it('should toggle selected state on dataset', function() {
        expect(this.vis.get('selected')).toBeTruthy();

        this.clickEl();
        expect(this.vis.get('selected')).toBeFalsy();
      });
    });
  });

  afterEach(function() {
    this.view.clean();
  });
});
