  /**
   *  Edit String dialog, comes from Small Dialog -> cell editor!
   *
   *  Associate templates:
   *    - dialog_small_edit
   */

  cdb.admin.EditStringDialog = cdb.admin.SmallDialog.extend({

    events: cdb.core.View.extendEvents({
      'keydown textarea': '_keyPress',
      'click': '_stopPropagation',
      'submit form': '_submit'
    }),

    initialize: function() {
      _.defaults(this.options, {
        template_name: 'common/views/dialog_small_edit',
        ok_title: 'Save',
        readOnly: this.options.readOnly,
        modal_class: 'edit_text_dialog',
        clean_on_hide: true
      });

      cdb.ui.common.Dialog.prototype.initialize.apply(this);
      this.render();
      $(document.body).find("div.table table").append(this.el);
    },


    render_content: function() {
      var val = this.options.initial_value || '';
      if(this.options.readOnly) {
        return '<textarea disabled="disabled" readOnly="true">' + val + '</textarea>';
      } else {
        return '<textarea>' + val + '</textarea>';
      }

    },


    /**
     *  Stop propagation click event
     */
    _stopPropagation: function(e) {
      e.stopPropagation();
    },


    /**
     *  Keypress
     */
    _keyPress: function(e) {
      if( (e.metaKey || e.ctrlKey) && e.keyCode == 13) {
        this._ok();
      }
    },

    _submit: function(e) {
      e.preventDefault();
      this._ok();
    },


    /**
     *  Overwrite the show function
     */
    showAt: function(x, y, width, fix) {
      this.$el.css({
        top: y,
        left: x,
        minWidth: width
      });

      if (fix) {
        this.$el.find("textarea").css({
          'min-width': width - 22
        })
      }

      this.show();
      this.$el.find("textarea")
        .focus()
        .select();
    },


    /**
     *  Ok function
     */
    ok: function() {
      if(this.options.res) {
        this.options.res(this.$('textarea').val());
      }
    }
  });
