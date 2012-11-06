describe('UserMenu', function() {
  var view;
  beforeEach(function() {
    view = new cdb.admin.DropdownMenu({
      speedIn: 250
    });
  });

  it("should open at position x, y", function() {
    runs(function() {
      view.openAt(11, 12)
    });

    waits(300);

    runs(function() {
      expect(view.$el.css('opacity')).toEqual('1');
      expect(view.$el.css('top')).toEqual('12px');
      expect(view.$el.css('left')).toEqual('11px');
    });
  });
});