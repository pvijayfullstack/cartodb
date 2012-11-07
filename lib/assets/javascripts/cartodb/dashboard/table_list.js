(function() {

  /**
   *  String prototype extend to represent property table size
   */
  String.prototype.bytesToSize = function() {
    var bytes = parseInt(this.toString())
      , sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    if (bytes == 0) return '0 KB';
    var i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
    var value = (bytes / Math.pow(1024, i)).toFixed(2);

    if (value % 1 == 0) {
      value = parseInt(value)
    }

    return value + " " + sizes[i];
  }



  /**
   * Single table item in dashboard list
   *
   * Usage example:
   *
      var li = new TableView({
        model: model*,
        limitation: !this.options.user.get("private_tables")
      });

      * It needs a table model to run correctly.
   *
   */
  var TableView = cdb.core.View.extend({

    tagName: 'li',

    events: {
      "click a.status": "_addPrivacySelector",
      "click a.delete": "_showDeleteConfirmation",
      "removeTag .tags a": "removeTag"
    },


    initialize: function() {
      _.bindAll(this, "render", "deleting", "deleted", "_addPrivacySelector", "removeTag", "_showDeleteConfirmation");

      _.defaults(this.options, this.default_options);

      this.template = cdb.templates.getTemplate('dashboard/views/table_list_item');

      // this.model.bind('destroy', this.clean, this);
      // this.model.bind('change', this.render, this);

      this.retrigger('saving', this.model);
      this.retrigger('saved', this.model);

      this.model.bind('updated', this.render);
      this.bind("clean", this._reClean, this);
    },


    render: function() {
      var self = this;
      this.cleanTooltips();
      this.$el.html(this.template(this.model.toJSON()));
      this.$el.addClass('tableRow')
      this.$el.droppable({
        hoverClass: "drop",
        drop: function( ev, ui ) {
          var tag = $(ui.helper).text()
            , tags = self.model.get("tags").split(",")
            , included = false;

          if (tags.indexOf(tag) < 0) {
            $.when(self.model.save({tags: tags + "," + tag})).done(function() {
              self.render();
              self.model.trigger('tagAdded');
            });
          }
          self.$el.removeClass('alreadyContainsTag').find('.right.tags a').removeClass('exists');
        },
        over: function(ev, ui) {
          var tag = $(ui.helper).text();
          self.$('.right.tags a').map(function(i,e) {
            var $element = $(e);
            if($element.html() == tag) {
              alreadyInserted = true;
              $element.addClass('exists');
              self.$el.addClass('alreadyContainsTag');
            }
          });
        },
        out: function() {
          self.$el.removeClass('alreadyContainsTag').find('.right.tags a').removeClass('exists');
        }
      });

      this.assignDraggables();
      return this;
    },
    /**
     * Hides the content and show a notification saying the table is being deleted
     * @triggers deleting
     * @return undefined
     */
    deleting: function() {
      this.cleanTooltips();
      this.trigger('deleting', this.model);
      this.$el.addClass('disabled');
    },

    /**
     * Close the "deleting" notification and warns the user that the table has been deleted
     * @triggers deleted
     * @return undefined
     */
    deleted: function() {
      this.trigger('deleted');
      this.cleanTooltips();
      this.$el.html('');

      var notificationTpl =
        '<p class="dark">Your table (' + this.model.get("name") + ') has been deleted</p>' +
        '<a class="smaller close" href="#close">x</a>';
      var $container = $('<li class="flash"></li>');
      this.$el.after($container);
      this.notification = new cdb.ui.common.Notification({
        el: $container,
        timeout:3000,
        template: notificationTpl,
        hideMethod: 'fadeOut',
        showMethod: 'fadeIn'
      });

      this.notification.open();
      this.$el.remove();

    },

    assignDraggables: function() {
        this.$('span.tags a').draggable({
        zIndex:9999,
        opacity: 1,
        helper: function(ev) {
          return $( "<a class='tag' href='#'>" + $(ev.currentTarget).html() + "</a>" );
        },
        start: function() {
          $('.removeTags').animate({opacity:1, height:"18px", padding:"10px 10px 10px 10px", borderWidth:"1px"},50);
        },
        stop: function() {
          $('.removeTags').animate({opacity:0, height:"0px", padding:"0px 0px 0px 10px", borderWidth:0},50);
        }
      });
    },

    removeTag: function(ev) {
      var tag = $(ev.currentTarget).html();
      var tags = this.model.get("tags").split(",");
      var position = tags.indexOf(tag);
      if(position > -1) {
        tags.splice(position, 1)
      }
      this.model.save({tags: tags.join(',')});
      this.model.trigger('tagRemoved');
      // this.trigger('tagRemoved');
      this.model.trigger('updated');

    },

    clean: function() {
      this.trigger('clean');
      this.elder('clean');
    },

    /**
     * Create the privacy selector after a "privacy link" clicked
     */
    _addPrivacySelector: function(ev) {
      ev && (ev.preventDefault());
      this.trigger('removePrivacy');

      this.privacy && this.privacy.clean();

      // this.options.limitation = true
      // Add privacy selector
      var privacy = this.privacy = new cdb.admin.PrivacySelector({
        model: this.model,
        limitation: this.options.limitation,
        upgrade_url: '/account/'+username+'/upgrade'
        // isn't any other way to catch the username than from a global?
      });

      cdb.god.bind("closeDialogs", this.privacy.hide, this.privacy);

      this.$el.append(this.privacy.render().el);

      this.privacy.show(ev.target);

      return false;
    },


    /**
     * Show delete confirmation after decides delete a table
     */
    _showDeleteConfirmation: function(ev) {
      var self = this;
      ev && (ev.preventDefault());
      this.trigger('deleteDialog');
      this.delete_dialog = new cdb.admin.DeleteDialog({
        model: this.model,
        config: this.options.config,
        ok: function() {
          self.deleted();
        }
      });
      this.delete_dialog.bind('deleting', function() { })
      this.delete_dialog.bind('deleted', function() { })
      this.retrigger('deleted', this.delete_dialog);

      $("body").append(this.delete_dialog.render().el);
      this.delete_dialog.open();
      this.delete_dialog.bind('deleting', self.deleting)
    },


    /**
     * Destroy droppable funcionality when el is being cleaned
     */
    _reClean: function() {
      this.clean();
      this.$el.droppable("destroy");
    }
  });


  /**
   * Tables list in the dashboard
   *
   * It will show up the user tables in a list
   *
   * Usage example:
   *
      var tableList = new cdb.admin.dashboard.TableList({
        el: this.$('#tablelist'),
        model: this.tables*,
        user: this.user**   // it needs it to know if the user has limitations or not
      });

      *   It needs a tables model to run correctly.
      **  It needs a user model to work properly.
   */

  var TableList = cdb.core.View.extend({
    tagName: 'ul',
    _TABLES_PER_PAGE: 10,
    events: {
      "click li:not('.disabled') a.delete": "markForDeletion"
    },

    initialize: function() {
      window.tl =  this;
      _.bindAll(this, "render", "appendTableByNumber", "_showLoader", "_hideLoader", "hardRender", "_updateListHeader", "_addAll", "_addTable", "_removeAllPrivacy", "markForDeletion");
      _.defaults(this.options, this.default_options);

      this.bindEvents();
    },

    bindEvents: function() {
      this.model.bind('reset',        this._addAll, this);
      this.model.bind('forceReload',  this.hardRender, this);
      this.model.bind('reset',        this._updateListHeader, this);
      this.model.bind('updated',      this._updateListHeader, this);
      this.model.bind('add',          this._updateListHeader, this);

      this.model.bind('updating', this._showLoader, this);
      this.model.bind('reset',    this._hideLoader, this);
      this.model.bind('updated',  this._hideLoader, this);
      this.model.bind('add',      this._hideLoader, this);

      this.model.bind('elementAdded', this.appendTableByNumber, this);
    },

    hardRender: function() {
      this.lastMarkedForDeletion = undefined;
      return this.render();
    },

    render: function() {
      var self = this;
      this.$el.html('');
      this._updateListHeader();
      if (this.model.length > 0) {
        this.model.each(function(m, i) {
          // if we are on the same position that the deleted table was, we insert the notification
          if(self.lastMarkedForDeletion) {
            if(self.lastMarkedForDeletion.pos == i) {
              self.showDeletedNotification();
            }
          }
          self._addTable(m);
          // each time a tag is removed, we forward the event to be able to refresh the tag list
          m.bind('tagRemoved', function() {
             self.model.trigger('tagRemoved');
             self.model.trigger('reset');
          });
          m.bind('tagAdded', function() {
             self.model.trigger('tagAdded');
             self.model.trigger('reset');
          });
          m.bind('deleted', function() {
            self.model.trigger('updated');
            self.model.trigger('reset');
          })

        });
        // if the lastMarkedForDeletion element was the last from the list, we shoudl add the notification at the end
        if(self.lastMarkedForDeletion && this.model.length <= self.lastMarkedForDeletion.pos) {
          this.showDeletedNotification();
        }
      } else {
        this._addEmpty();
      }
      this.trigger('renderComplete');
    },

    showDeletedNotification: function() {
      var self = this;
      if(this.lastMarkedForDeletion) {
        this.$('.notificationContainer').remove();

        var notificationTpl =
          '<p class="dark">Your table (' + this.lastMarkedForDeletion.name + ') has been deleted</p>' +
          '<a class="smaller close" href="#close">x</a>';

        var $container = $('<li class="flash"></li>');
        this.$el.append($container);
        if(this.notification && this.notification.destroy) {
          this.notification.removeData().unbind().remove().clean();
          delete this.notification;
        }
        this.notification = new cdb.ui.common.Notification({
          el: $container,
          timeout:10000,
          template: notificationTpl,
          hideMethod: 'fadeOut',
        });
        this.notification.unbind('notificationDeleted');
        this.notification.bind('notificationDeleted', function() {
          self.notificationShowing = false;
        })
        if(self.notificationShowing) {
          self.notification.open();
          self.notificationShowing = true;
        } else {
          self.notification.open('', function() {
            self.notificationShowing = true;
          });
        }

      }
    },

    _addEmpty: function() {
      this.$el.append(cdb.templates.getTemplate('dashboard/views/table_list_empty'))
    },


    /**
     * Add all list
     */
    _addAll: function() {

      if(!this.modelLoaded) {
        this.modelLoaded = true;
        this.render();
      } else {
        if(this.model.length == 0) {
          this.render();
          this._hideLoader();
        }
      }
    },


    /**
     * Add single table view
     */
    _addTable: function(m) {
      var self = this;
      var li = new TableView({ model: m, config: this.options.config, limitation: !this.options.user.get("private_tables") });
      li.bind('removePrivacy', this._removeAllPrivacy);
      this.$el.append(li.render().el);
      this.addView(li);
      this._updateListHeader();
      li.bind('saving', function() {
        self.model.trigger('updating');
      });
      li.bind('saved', function() {
        self.model.trigger('updated')
      })
      li.bind('deleted', function() {
        self.model.trigger('updated')
        self.model.trigger('reset');
        self.refreshTable();
      })
      li.bind('deleting', function(model) {
        self.model.trigger('updating');
        self.model.remove(model);
      })
    },

    /**
     * Checks if the table is uncompensated (has less tan _TABLES_PER_PAGE entries but has a next page)
     * and if needed, fills the gap
     */
    refreshTable: function() {
      var self = this;
      if(!this.checkTableListFull()) {
        this.model.refillTableList(this._TABLES_PER_PAGE);
      }
    },


    /**
     * Extract the n table from model and append it to the view
     * @param  {Integer} n
     */
    appendTableByNumber: function(n) {
      if(this.model.models[n]) {
        this._addTable(this.model.models[n]);
      }
    },

    /**
     * Checks if there are more less than ten tables loaded (because a deletion)
     * and that there are more tables after the current pages.
     * @return {[type]} [description]
     */
    checkTableListFull: function() {
      if(this.model.models.length < this._TABLES_PER_PAGE &&
        this.model.total_entries >= this._TABLES_PER_PAGE) {
          return false;
      }
      return true;
    },


    _removeAllPrivacy: function() {
      for(var v in this._subviews) {
        this._subviews[v].privacy && this._subviews[v].privacy.clean();
      }
    },

    markForDeletion: function(ev) {
      ev.preventDefault();
      ev.stopPropagation();

      var tableInfo = $(ev.currentTarget).parents('.tableRow');

      var tableIndex = this.$('.tableRow').index(tableInfo)
      this.lastMarkedForDeletion = {
        "pos": tableIndex,
        "name": this.$('.tableRow h3 a').html(),
        "li": tableInfo
      };

      self.notificationShowing = false;
      if(this.notification) {
        this.notification.hide()
      }
    },

    /**
     * After a table removed
     */
    _tableRemoved: function() {
      this._updateListHeader();
    },


    /**
     * Update the counter of tables
     */
    _updateListHeader: function(sync) {
      var title =  this.model.total_entries + " " + ( this.model.total_entries != 1 ? "tables" : "table" );

      if (this.model.options.attributes.tag_name != "")
        title += " with tag <a class='remove' href='#/'>" + decodeURIComponent(this.model.options.attributes.tag_name) + "</a>";

      if (this.model.options.attributes.q != "")
        title += " with <a class='remove' href='#/'>" + this.model.options.attributes.q +  "</a> found";

      if (this.model.options.attributes.q == "" && this.model.options.attributes.tag_name == "")
        title += " in your account";

      $("section.tables > div.head > h2").html(title);
    },


    /**
     * Show the loader when the table model is operating
     */
    _showLoader: function() {
      $("section.tables > div.head > div.loader").fadeIn();
    },


    /**
     * Hide the loader when the table model is operating
     */
    _hideLoader: function() {
      $("section.tables > div.head > div.loader").fadeOut();
    }
  });

  cdb.admin.dashboard.TableList = TableList;
})();
