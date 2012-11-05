
cdb.admin.RenameConfirmationDialog = cdb.admin.BaseDialog.extend({

  initialize: function() {
    _.extend(this.options, {
      title: "Rename this table",
      description: '',
      template_name: 'common/views/dialog_base',
      clean_on_hide: true,
      ok_button_classes: "button grey",
      ok_title: "Ok, continue",
      cancel_button_classes: "underline margin15",
      modal_type: "confirmation",
      width: 510,
      modal_class: 'rename_table_confirmation_dialog'
    });
    this.constructor.__super__.initialize.apply(this);
    this.dfd = $.Deferred();
  },

  render_content: function() {
    return this.getTemplate('table/views/rename_table_confirmation')();
  },

  confirm: function() {
    return this.dfd.promise();
  },

  ok: function(ev) {
    var self = this;
    self.model.save({ name: self.options.newName }, {wait: true});
    this.dfd.resolve(self.options.newName);
  }
});
