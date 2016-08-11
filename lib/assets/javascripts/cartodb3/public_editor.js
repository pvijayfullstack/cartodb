var deepInsights = require('cartodb-deep-insights.js');
var _ = require('underscore');
var URLStateHelper = require('cartodb-deep-insights.js/src/api/url-helper.js');
var vizJSON = _.extend(
  window.vizJSON,
  {
    legends: false
  }
);
var dashboardOpts = {
  no_cdn: false,
  cartodb_logo: false,
  renderMenu: true,
  share_urls: true,
  authToken: window.authTokens
};
var stateJSON = window.stateJSON;
var stateFromURL = URLStateHelper.getStateFromCurrentURL();
if (stateFromURL && !_.isEmpty(stateFromURL)) {
  _.extend(dashboardOpts, {
    state: stateFromURL
  });
} else if (stateJSON && stateJSON !== '{}') {
  _.extend(dashboardOpts, {
    state: stateJSON
  });
}
deepInsights.createDashboard('#dashboard', vizJSON, dashboardOpts, function (error, dashboard) {
  if (error) {
    console.error('Dashboard has some errors:', error);
  }

  var map = dashboard.getMap().map;
  var scrollwheel = vizJSON.scrollwheel;
  var method = scrollwheel ? 'enableScrollWheel' : 'disableScrollWheel';
  map && map[method] && map[method]();
});
