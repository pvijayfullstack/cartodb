<div class="CDB-Text CDB-Fieldset u-tSpace-xl">
  <div class="CDB-Legend CDB-Legend--big u-ellipsis u-upperCase u-iBlock CDB-Text is-semibold CDB-Size-small u-rSpace--m">
    <div class="CDB-Shape u-iblock u-malign">
      <div class="CDB-Shape-rectsHandle is-small">
        <div class="CDB-Shape-rectsHandleItem CDB-Shape-rectsHandleItem--grey is-first"></div>
        <div class="CDB-Shape-rectsHandleItem CDB-Shape-rectsHandleItem--grey is-second"></div>
        <div class="CDB-Shape-rectsHandleItem CDB-Shape-rectsHandleItem--grey is-third"></div>
      </div>
    </div>
    <input class="CDB-Checkbox js-checkbox" type="checkbox" <% if (isSelected) { %>checked="checked"<% } %>">
    <span class="u-iBlock CDB-Checkbox-face u-rSpace--m"></span>
    <label class="u-rSpace--m" title="<%- name %>"><%- name %></label>
  </div>
  <input type="text" name="text" placeholder='"<%- name %>"' value="<% if (!isSelected) { %><%- name %><% } else { %><% if (title) { %><% if (alternativeName) { %><%- alternativeName %><% } else { %><%- name %><% } %><% } %><% } %>" class="CDB-InputText js-input" <% if (!isSelected) { %>disabled<% } %>>
</div>
