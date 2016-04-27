var $ = require('jquery');
var _ = require('underscore');
var Backbone = require('backbone');
require('backbone-forms');
Backbone.$ = $;

// Custom validators
_.extend(
  Backbone.Form.validators,
  {
    interval: require('./validators/interval.js')
  }
);

// Requiring custom form components
require('./field.js');
require('./editors/text.js');
require('./editors/radio.js');
require('./editors/select.js');
require('./editors/number.js');
require('./editors/textarea.js');
require('./editors/fill.js');
