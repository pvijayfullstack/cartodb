<button type="button" class="CDB-ColorBarContainer CDB-OptionInput-content">
  <ul class="CDB-ColorBarContainer">
    <% if (_.isArray(value)) { %>
    <li class="CDB-ColorBar CDB-ColorBar--spaceless" style="background: linear-gradient(90deg,<%- value.join(',') %>)"></li>
    <% } else { %>
    <li class="CDB-ColorBar" style="background-color: <%- value %>; opacity: <%- opacity %>"></li>
    <% } %>
  </ul>
</button>
