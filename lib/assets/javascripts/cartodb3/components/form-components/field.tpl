<div class="CDB-Text Editor-formInner">
  <% if (title) { %>
    <label class="CDB-Legend <% if (editorType){ %> CDB-Legend--<%- editorType %><% } %> u-upperCase u-ellipsis CDB-Text is-semibold CDB-Size-small u-rSpace--m" for="<%- editorId %>" title="<%- title %>">
      <span class="<% if (help) { %> js-help is-underlined<% } %>" <% if (help) { %> data-tooltip="<%- help %>"<% } %> ><%- title %></span>
    </label>
  <% } %>
  <div class="Editor-formInput u-flex u-alignCenter" data-editor>
    <% if (copy) { %>
      <button type="button" class="Share-copy CDB-Button CDB-Button--small js-copy" data-clipboard-target="#<%- editorId %>">
        <span class="CDB-Button-Text CDB-Text CDB-Size-small u-actionTextColor"><%- copy %></span>
      </button>
    <% } %>
  </div>
</div>
