<div class="Dialog-header ErrorDetails-header">
  <div class="Dialog-headerIcon Dialog-headerIcon--negative">
    <i class="CDB-IconFont CDB-IconFont-barometer"></i>
  </div>
  <p class="Dialog-headerTitle"><%- _t('components.background-importer.layers-error-details-upgrade.reached-limits') %></p>
  <p class="Dialog-headerText"><%- _t('components.background-importer.layers-error-details-upgrade.remove-or-upgrade') %></p>
</div>
<div class="Dialog-body ErrorDetails-body ErrorDetails-body--no-line">
  <div class="UpgradeElement">
    <div class="UpgradeElement-info">
      <div class="LayoutIcon UpgradeElement-infoIcon">
        <i class="CDB-IconFont CDB-IconFont-rocket"></i>
      </div>
      <p class="UpgradeElement-infoText u-ellipsLongText">
        <%- _t('components.background-importer.layers-error-details-upgrade.keep-your-maps') %></p>
    </div>
    <% if (showTrial) { %>
      <div class="UpgradeElement-trial">
        <i class="CDB-IconFont CDB-IconFont-gift UpgradeElement-trialIcon"></i>
        <p class="UpgradeElement-trialText u-ellipsLongText"><%- _t('components.background-importer.free-trial', { days: 14 }) %></p>
      </div>
    <% } %>
  </div>
</div>
<div class="Dialog-footer ErrorDetails-footer ErrorDetails-footer--no-line">
  <a href="<%- upgradeUrl %>" class="Button Button--main ErrorDetails-footerButton">
    <span><%- _t('components.background-importer.layers-error-details-upgrade.upgrade') %></span>
  </a>
</div>
