cdb.admin.DEFAULT_LAYERS = [
  {
  url: 'https://maps.nlp.nokia.com/maptiler/v2/maptile/newest/normal.day/{z}/{x}/{y}/256/png8?lg=eng&token=A7tBPacePg9Mj_zghvKt9Q&app_id=KuYppsdXZznpffJsKT24',
  minZoom: 0,
  maxZoom: 21,
  name: 'Nokia Day',
  className: "nokia_day",
  attribution: "©2012 Nokia <a href='http://here.net/services/terms' target='_blank'>Terms of use</a>"
}, {
  url: 'http://{s}.api.cartocdn.com/base-light/{z}/{x}/{y}.png',
  minZoom: 0,
  maxZoom: 10,
  name: 'CartoDB Light',
  className: "light_cartodb",
  attribution: ""
}, {
  url: 'http://{s}.api.cartocdn.com/base-dark/{z}/{x}/{y}.png',
  minZoom: 0,
  maxZoom: 10,
  name: 'CartoDB Dark',
  className: "dark_cartodb",
  attribution: ""
}, {
  url: 'http://{s}.api.cartocdn.com/base-flatblue/{z}/{x}/{y}.png',
  minZoom: 0,
  maxZoom: 10,
  name: 'CartoDB Flat Blue',
  className: "flat_blue",
  attribution: ""
} ];
