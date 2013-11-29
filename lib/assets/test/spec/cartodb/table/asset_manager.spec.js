
  describe("Asset manager", function() {

    var view, server;
    
    beforeEach(function() {
      cdb.config = new cdb.core.Model({ dropbox_api_key: 'j'})
      view = new cdb.admin.AssetManager({
        user: { id: 1 },
        kind: 'marker'
      })
      server = sinon.fakeServer.create();
    });

    afterEach(function() {
      view.clean();
    })

    it("should render properly", function() {
      view.render();
      server.respondWith('/api/v1/users/1/assets', [200, { "Content-Type": "application/json" }, '{total_entries:0, assets: []}']);
      server.respond();
      expect(view.upload_panes.size()).toBe(2);
      expect(view.model.get('state')).toBe('idle');
      expect(view.assets_collection.size()).toBe(0);
      expect(view.$('.ok').hasClass('disabled')).toBeTruthy();
    });

    it("should re-render assets list when there is a change in the assets collection", function() {
      view.render();
      view.assets_collection.reset([]);
      expect(view.$('div.assets-list').css('display')).toBe('none')
    });

    it("should render two assets item", function() {
      view.render();
      view.assets_collection.reset([{
        public_url: 'http://com.cartodb.assets.dev.s3.amazonaws.com/development/dev/assets/layers.png',
        kind: 'marker',
        id: 57
      },{
        public_url: 'http://com.cartodb.assets.dev.s3.amazonaws.com/development/dev/assets/layers.png',
        kind: 'marker',
        id: 58
      },{
        public_url: 'http://com.cartodb.assets.dev.s3.amazonaws.com/development/dev/assets/layers.png',
        kind: 'pattern',
        id: 59
      }
      ]);
      expect(view.$('div.assets-list').css('display')).toBe('block')
      expect(view.$('ul.assets-list li').size()).toBe(2);
    });

    it("should active ok button when selects an asset item", function() {
      view.render();
      view.assets_collection.reset([{
        public_url: 'http://com.cartodb.assets.dev.s3.amazonaws.com/development/dev/assets/layers.png',
        kind: 'marker',
        id: 57
      },{
        public_url: 'http://com.cartodb.assets.dev.s3.amazonaws.com/development/dev/assets/layers.png',
        kind: 'marker',
        id: 58
      }]);

      view.$('ul.assets-list li a.image').click();
      expect(view.$('.ok').hasClass('disabled')).toBeFalsy();
      expect(view._isEnabled()).toBeTruthy();
    });

    it("should upload the file url when user has written it", function() {
      view.render();
      spyOn(view.filePane, 'submitUpload');
      console.log(view.filePane);

      view.$('input.url-input').val('http://test.com/test.png');
      view.$('input.url-input').keyup();
      view.$('.ok').click();
      expect(view.$('.ok').hasClass('disabled')).toBeFalsy();
      expect(view._isEnabled()).toBeFalsy();
      expect(view.filePane.submitUpload).toHaveBeenCalled();
    });

    it("shouldn't show sync block when user types a valid url", function() {
      view.render();

      view.$('input.url-input').val('http://test.com/test.png');
      view.$('input.url-input').keyup();

      expect(view.$('.info.no-sync').css('display')).toBe('none');
      expect(view.$('.info.sync').css('display')).toBe('none');
    });


    it("should show an error when a file upload fails", function() {
      view.render();
      spyOn(view, '_onUploadError');
      spyOn(view, '_changeState');

      view._uploadFromUrl({
        type: 'url',
        value: 'i_love_this_image.png'
      });
      
      expect(view.model.get('state')).toBe('uploading');
      expect(view.$('.upload-progress').css('opacity')).toBeGreaterThan(0);
      expect(view._changeState).toHaveBeenCalled();
      
      server.respondWith("POST", '/api/v1/users/1/assets', [400, { "Content-Type": "application/json" }, '{total_entries:0, assets: []}']);
      server.respond();
      
      expect(view._onUploadError).toHaveBeenCalled();
      expect(view.assets_collection.size()).toBe(0);
      expect(view.$('ul.assets-list li').size()).toBe(0);
    });
  });
