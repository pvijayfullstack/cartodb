
/**
 *  Pattern image base layer
 *
 *  - It extends from color basemap
 */

cdb.admin.BackgroundMapImageView = cdb.admin.BackgroundMapColorView.extend({

  events: {
    'click': '_openImagePicker'
  },

  initialize: function() {
    _.bindAll(this, 'setPattern');
    this.map = this.options.map;
    this.template = cdb.templates.getTemplate('table/views/basemap/pattern_basemap');
    this.bindMap(this.map);
    this.map.bind('savingLayersFinish', this._changeModel, this);
    this._initBinds();
  },

  activate: function(url) {
    var lyr = new cdb.admin.PlainLayer({
      color: '',
      image: url,
      maxZoom: 28 //allow the user to zoom to the atom
    });

    this.model = lyr;

    this.map.changeProvider('leaflet', lyr);

    return false;
  },

  _openImagePicker: function(e) {
    this.killEvent(e);

    var imagePicker = new cdb.admin.AssetManager({
      user: window.user_data, // TODO: assets manager should not rely on user data
      kind: 'pattern'
    });

    imagePicker.appendToBody().open();
    imagePicker.bind('fileChosen', this.setPattern, this);
  },

  setPattern: function(url) {
    cdb.god.trigger("closeDialogs");

    // Set new model
    this.activate(url);

    // Render color
    this.render();

    // Set general thumb
    //$("ul.options .basemap_dropdown .info strong").text("Image pattern");
    $("ul.options .basemap_dropdown a.thumb")
      .css({
        "background-image": "url(" + url + ")",
        "background-size": "34px",
        "background-position": "50% 50%",
        "background-color": "transparent"
      });

    this.selectButton();

    // Hubspot tracking "Applied pattern as basemap"
    cdb.god.trigger('hubspot', '000000265935', {
      email: window.user_data.email,
      data: { url: url }
    });
  }

});
