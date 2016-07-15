<div class="Share-permissionInfo">
  <div class="Share-permissionIcon">
    <% if (avatar) { %>
        <img src="<%- avatar %>" class="UserAvatar-img UserAvatar-img--medium" />
    <% } else { %>
        <i class="CDB-IconFont CDB-IconFont-people"></i>
    <% } %>
  </div>
  <div>
    <div class="CDB-Text u-mainTextColor CDB-Size-medium is-semibold u-ellipsis">
      <%- name %>
      <% if (role) { %>
        <i class="Tag Tag--outline CDB-Text CDB-Size-small u-upperCase u-lSpace--xl"><%- role %></i>
      <% } %>
    </div>
    <% if (description) { %>
    <p class="CDB-Text u-mainTextColor u-tSpace CDB-Size-medium u-ellipsis">
      <%- description %>
    </p>
    <% } %>
  </div>
</div>
<div class="Share-togglers">
  <% if (hasWriteAccessAvailable) { %>
    <div class="CDB-Text CDB-Size-medium u-rSpace--xl Share-toggler js-toggler <% if (!canChangeWriteAccess) { %>is-disabled<% } %>">
      <input class="CDB-Toggle u-iBlock js-write" type="checkbox"
        <% if (!canChangeWriteAccess) { %>disabled="disabled"<% } %>
        <% if (hasWriteAccess) { %> checked <% } %>
      />
      <span class="u-iBlock CDB-ToggleFace"></span>
      <label class="u-iBlock u-altTextColor "><%- _t('components.modals.share-org.toggle.write') %></label>
    </div>
  <% } %>
  <div class="CDB-Text CDB-Size-medium Share-toggler js-toggler <% if (!canChangeReadAccess) { %>is-disabled<% } %>">
    <input class="CDB-Toggle u-iBlock js-read" type="checkbox"
      <% if (hasReadAccess) { %> checked <% } %>
      <% if (!canChangeReadAccess) { %>disabled="disabled"<% } %>
    />
    <span class="u-iBlock CDB-ToggleFace"></span>
    <label class="u-iBlock u-altTextColor "><%- _t('components.modals.share-org.toggle.read') %></label>
  </div>
</div>