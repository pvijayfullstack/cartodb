var cdb = require('cartodb.js');
cdb.admin = require('cdb.admin');
var bytesToSize = require('./bytes_to_size');

/**
 * The content of the dropdown menu opened by the user avatar in the top-right of the header, e.g.:
 *   Explore, Learn, ♞
 *             ______/\____
 *            |            |
 *            |    this    |
 *            |____________|
 */
module.exports = cdb.admin.DropdownMenu.extend({
  initialize: function(args) {
    this.constructor.__super__.initialize.apply(this);

    this.userUrls = args.userUrls;
    this.add_related_model(this.userUrls);
  },

  render: function() {
    var user = this.model;
    var usedDataBytes = user.get('db_size_in_bytes');
    var availableDataSize = user.get('quota_in_bytes');

    this.$el.html(this.template_base({
      name:         user.get('name') || user.get('username'),
      email:        user.get('email'),
      accountType:  user.get('account_type').toLowerCase(),
      isOrgAdmin:   user.isOrgAdmin(),
      usedDataStr:      bytesToSize(usedDataBytes).toString(),
      usedDataPct:      Math.round(usedDataBytes/availableDataSize * 100),
      availableDataStr: bytesToSize(availableDataSize).toString(),
      showUpgradeLink:  this.userUrls.hasUpgradeUrl() && (user.isOrgAdmin() || !user.isInsideOrg()),
      upgradeUrl:       this.userUrls.upgradeUrl(),
      publicProfileUrl:   this.userUrls.publicProfileUrl(user),
      apiKeysUrl:         this.userUrls.apiKeysUrl(),
      accountSettingsUrl: this.userUrls.accountSettingsUrl(user),
      logoutUrl:          this.userUrls.logoutUrl()
    }));

    // Necessary to hide dialog on click outside popup, for example.
    cdb.god.bind('closeDialogs', this.hide, this);

    // TODO: taken from existing code, how should dropdowns really be added to the DOM?
    $('body').append(this.el);

    return this;
  }
});
