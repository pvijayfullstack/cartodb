
/**
 * shows a dialog to get the table exported
 * new ExportTableDialog({
 *  table: table_model
 * })
 *
 */
cdb.admin.ExportTableDialog = cdb.admin.BaseDialog.extend({

  events: cdb.core.View.extendEvents({
    'click nav a': 'hide'
  }),

  initialize: function() {
    _.extend(this.options, {
      title: "Select your file type",
      description: '',
      template_name: 'common/views/dialog_base',
      clean_on_hide: true,
      ok_button_classes: "button grey",
      ok_title: "",
      modal_type: "",
      width: 510,
      modal_class: 'export_table_dialog',
      include_footer: false,
      table_id: this.model.id
    });
    this.constructor.__super__.initialize.apply(this);
  },

  getSqlApiUrl: function() {
    var sql = '';
    var filename = '';
    var baseUrl = this.options.config.sql_api_protocol + '://' + this.options.config.sql_api_domain
      + ':'
      + this.options.config.sql_api_port
      + '/api/v1/sql?';
    if(this.options.sql) {
      sql = this.options.sql;
    }
    else if(this.model.sqlView) {
      sql = this.model.sqlView.getSQL();
      filename = 'cartodb_query';
    } else {
      sql = "select * from " + this.model.get('name')
      filename = this.model.get('name');
    }
    baseUrl += 'q='+sql;
    baseUrl += '&filename='+filename;
    if(this.options.user_data) {
      baseUrl += '&api_key=' + this.options.user_data.api_key;
    }
    return baseUrl;
  },

  render_content: function() {
    return this.getTemplate('common/views/export_table_dialog')({sqlUrl:this.getSqlApiUrl()});
  }
});
