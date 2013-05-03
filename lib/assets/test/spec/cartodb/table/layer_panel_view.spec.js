describe("cdb.admin.LayerPanelView", function() { 

  var view;
  var map, table, sqlView, user, layer, vis;
  beforeEach(function() {
    map = new cdb.admin.Map();

    user = new cdb.admin.User({
      username: 'testusername',
      api_key: 'rabos'
    });

    vis = new cdb.admin.Visualization({
      map_id:  96,
      name:    "test_table",
      privacy: "PUBLIC",
      type:    "table"
    });

    var globalError = new cdb.admin.GlobalError({
      el: $('<div>')
    });

    layer = new cdb.admin.CartoDBLayer({
      table_name: 'test',
      id: 10,
      visible: 'true'
    });

    table = layer.table;
    map.layers.add(layer);


    view = new cdb.admin.LayerPanelView({
      model: layer,
      vis: vis,
      map: map,
      user: user,
      globalError: globalError
    });
  });

  it("should add map_key in layer", function() {
    expect(layer.get('extra_params').map_key).toEqual('rabos');
  });

  it("should hide/show the layer", function() {
    view.hide();
    expect(view.$('.sidebar').css('display')).toEqual('none');
    expect(view.$('.views').css('display')).toEqual('none');

    view.show();
    expect(view.$('.sidebar').css('display')).toEqual('block');
    expect(view.$('.views').css('display')).toEqual('block');
  });


  describe("layer initialization", function() {

    beforeEach(function() {
      //view.vis.set('type', 'derived');
    });

    it("should have 4 modules + 3 action buttons", function() {
      expect(view.buttons.length).toBe(7);
    });
  });


  describe("buttons behavior", function() {

    it("should show all the buttons when no sql is applied", function() {
      view.setActiveWorkView('table');
      var e = _(view.enabledButtonsForSection('table')).filter(function(b) {
        return b.$el.css('display') != 'none'
      });
      expect(e.length).toEqual(4);

      view.setActiveWorkView('map');
      var e = _(view.enabledButtonsForSection('map')).filter(function(b) {
        return b.$el.css('display') != 'none'
      });
      expect(e.length).toEqual(4);
    });

    it("should show readonly buttons when sql is applied", function() {
      table.useSQLView(view.sqlView);
      view.setActiveWorkView('table');
      var e = _(view.enabledButtonsForSection('table')).filter(function(b) {
        return b.$el.css('display') != 'none'
      });
      expect(e.length).toEqual(1);

      view.setActiveWorkView('map');
      var e = _(view.enabledButtonsForSection('map')).filter(function(b) {
        return b.$el.css('display') != 'none'
      });
      expect(e.length).toEqual(4);
    });

    it("should show change to readonly buttons when sql is applied", function() {
      view.setActiveWorkView('table');
      table.useSQLView(view.sqlView);
      view.sqlView.modify_rows = false;
      view.sqlView.trigger('reset');
      var e = _(view.enabledButtonsForSection('table')).filter(function(b) {
        return b.$el.css('display') != 'none'
      });
      expect(e.length).toEqual(1);
    });
  });

  describe("layer info", function() {

    it("should set layer name, order and options", function() {
      expect(view.$('.layer_info a.info .name').text()).toBe('test');
      expect(view.$('.layer_info a.info .order').text()).toBe('1');
      expect(view.$('.layer_info div.right').css("display")).toBe('none');
    });

    it("should show layer option buttons if the visualization is the type derived", function() {
      view.vis.set('type', 'derived');
      expect(view.$('.layer_info div.right').css("display")).toBe('block');
    });

    it("should change the layer name if it changes", function() {
      view.dataLayer.set('table_name', 'jam');
      expect(view.$('.layer_info a.info .name').text()).toBe('jam');
    });

    it("shouldn't change the layer order if it changes, due to the visualization is the type table", function() {
      view.dataLayer.set('order', '4');
      expect(view.$('.layer_info a.info .order').text()).toBe('1');
    });

    it("should change the layer order if it changes", function() {
      view.vis.set('type', 'derived');
      view.dataLayer.set('order', '4');
      expect(view.$('.layer_info a.info .order').text()).toBe('4');
    });

  });

  describe("layer actions", function() {

    beforeEach(function() {
      view.vis.set('type', 'derived');
    });

    it("should remove the layer", function() {
      view.$('a.remove').trigger('click');
      expect(view.remove_dlg).not.toBe(null);
      view.remove_dlg.clean();
    });

    it("should toggle the layer", function() {
      view.$('a.visibility').trigger('click');
      expect(view.model.get('visible')).toBeFalsy();
    });

    it("should active the layer", function() {
      view.$('a.info').trigger('click');
      expect(view.vis.get('active_layer_id')).toBe(10);
    });

    it("shouldn't remove a layer if visualization is a table type", function() {
      view.vis.set('type', 'table');
      view.$('a.remove').trigger('click');
      expect(view.remove_dlg).toBe(undefined);
    });

    it("shouldn't change layer visibility if visualization is a table type", function() {
      view.vis.set('type', 'table');
      view.$('a.visibility').trigger('click');
      expect(view.model.get('visible')).toBeTruthy();
    });
  });
  
});
