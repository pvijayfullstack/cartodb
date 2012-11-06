
describe("", function() {

  describe("sharemapdialog", function() {
    var view;
    beforeEach(function() {
      var map = new cdb.admin.Map();
      map.setBounds([1,2], [3,4]);
      var table = TestUtil.createTable('test');
      map.layers.add(new cdb.geo.MapLayer());
      map.layers.add(new cdb.geo.CartoDBLayer({ query: 'select * from rambo'} ));
      view = new cdb.admin.ShareMapDialog({
        map: map,
        table: table
      });
    });

    it("should render 3 panels", function() {
      view.render();
      expect(_.keys(view.panels._subviews).length).toEqual(3);
    });

  });

  describe("sharemap", function() {
    var view, table, map;
    beforeEach(function() {
      map = new cdb.admin.Map();
      map.setBounds([[1,2], [3,4]]);
      map.layers.add(new cdb.geo.TileLayer({ urlTemplate: 'http://test.com'}));
      map.layers.add(new cdb.geo.CartoDBLayer({ query: 'select * from rambo', table_name: 'test', user_name: 'test'} ));
      table = TestUtil.createTable('test');

      mapOptions = new cdb.core.Model({
        title: true,
        description: true,
        search: false,
        shareable: false,
        sql: ''
      });

      view = new cdb._test.MapShareTab({
        map: map,
        table: table,
        mapOptions: mapOptions
      });

    });

    it("should render a map with controls", function() {
      view.render().show();
      expect(view.$('#zoom').length).toEqual(1);
      expect(view.$('div.header h1').html()).toEqual('test');
      expect(view.$('div.header p').html()).toEqual('test description');
      expect(view.$('.form_switch').length).toEqual(4);
    });

    it("should set url", function() {
      runs(function() {
        view.render().show();
        expect(view.$('.url').html().indexOf('title=true')).not.toEqual(-1);
        view.mapOptions.set({title: false});
        expect(view.$('.url').html().indexOf('title=false')).not.toEqual(-1);
        expect(view.$('.url').html().indexOf('sql')).not.toEqual(-1);
      });
      // wait to map is shown
      waits(1200);

      runs(function() {
        expect(view.$('.url').html().indexOf('sw_lat')).not.toEqual(-1);
      });
    });

    it("should set url with sql from layer", function() {
      var sql;
      var sqlView = new cdb.admin.SQLViewData();
      sqlView.setSQL(sql='select * from charlies limit 1');
      table.useSQLView(sqlView);
      view.render().show();
      expect(view.$('.url').html().indexOf('sql=' + encodeURIComponent("select * from rambo"))).not.toEqual(-1);
    });


    it("should hide header when change options", function() {
      view.render().show();
      view.mapOptions.set({title: false});
      view.mapOptions.set({description: false});
      view.mapOptions.set({shareable: false});
      expect(view.$('div.header').css('display')).toEqual('none');
    });
  });

});
