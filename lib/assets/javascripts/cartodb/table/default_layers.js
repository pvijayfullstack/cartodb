cdb.admin.DEFAULT_LAYERS = [
  {
    url: 'https://maps.nlp.nokia.com/maptiler/v2/maptile/newest/normal.day/{z}/{x}/{y}/256/png8?lg=eng&token=A7tBPacePg9Mj_zghvKt9Q&app_id=KuYppsdXZznpffJsKT24',
    maxZoom: 21,
    name: 'Nokia Day',
    className: "nokia_day",
    attribution: "©2012 Nokia <a href='http://here.net/services/terms' target='_blank'>Terms of use</a>"
  }, {
    url: 'https://dnv9my2eseobd.cloudfront.net/v3/cartodb.map-eeoepub0/{z}/{x}/{y}.png',
    maxZoom: 21,
    name: 'MapBox Streets',
    className: "mapbox_streets",
    attribution: "MapBox <a href='http://mapbox.com/about/maps' target='_blank'>Terms &amp; Feedback</a>"
  }, {
    url: 'https://dnv9my2eseobd.cloudfront.net/v3/cartodb.map-41exmwk3/{z}/{x}/{y}.png',
    maxZoom: 21,
    name: 'MapBox Terrain',
    className: "mapbox_terrain",
    attribution: "MapBox <a href='http://mapbox.com/about/maps' target='_blank'>Terms &amp; Feedback</a>"
  }
];
