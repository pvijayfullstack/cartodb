<form>
  <fieldset>
    <% _.each(fields, function(field) { %>
      <div class="u-tSpace-xl CDB-Text">
        <input class="CDB-Checkbox" type="checkbox" name="fields" value="<%- field.get('name') %>">
        <span class="u-iBlock CDB-Checkbox-face"></span>
        <p class="CDB-Legend u-upperCase u-iBlock CDB-Text is-semibold CDB-Size-small u-rSpace--m">
          <%- field.get('name') %>
        </p>
        <div class="CDB-Text CDB-Size-medium u-iBlock">
          <input class="CDB-InputText" type="text" value="<%- field.get('name') %>">
        </div>
      </div>
    <% }); %>
  </fieldset>
</form>
