
describe("privacy_selector", function() {
  var privacy_selector, vis;

  beforeEach(function() {
    vis = new cdb.admin.Visualization({
      map_id:           96,
      active_layer_id:  null,
      name:             "test_table",
      description:      "Visualization description",
      tags:             ["jamon","probando","test"],
      privacy:          "PUBLIC",
      updated_at:       "2013-03-04T18:09:34+01:00",
      type:             "table"
    });

    privacy_selector = new cdb.admin.PrivacySelector({
      model: vis,
      limitation: true,
      direction: 'down',
      upgrade_url: window.location.protocol + "//test.localhost.lan/account/development/upgrade"
    });
  });

  it("should render properly when you can't change to private tables", function() {
    privacy_selector.render();
    expect(privacy_selector.$('span.radio').length).toEqual(0);
    expect(privacy_selector.$('p:contains("Privacy and visibility options are only available on paid accounts.")').length).toEqual(1);
  });

  it("should render properly when you can change to private tables", function() {
    var new_privacy = new cdb.admin.PrivacySelector({
      model: vis,
      limitation: false,
      direction: 'down',
      upgrade_url: window.location.protocol + "//test.localhost.lan/account/development/upgrade"
    });

    new_privacy.render();
    expect(new_privacy.$('span.radio').length).toEqual(3);
    expect(new_privacy.$('li a:contains("Public on the web")').length).toEqual(1);
    expect(new_privacy.$('li a:contains("Anyone with a link")').length).toEqual(1);
    expect(new_privacy.$('li a:contains("Private")').length).toEqual(1);
  });

});
