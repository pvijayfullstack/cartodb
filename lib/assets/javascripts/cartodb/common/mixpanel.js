
  /**
   *  Mixpanel class for CartoDB
   *
   *  - Track user events in CartoDB. Mixpanel is created
   *  from the beginning as a global variable, so it is
   *  called as it is created.
   *  - When an event is launched, you can use our God to
   *  save the action (cdb.god.trigger('mixpanel', "Import failed")).
   *
   *  new cdb.admin.Mixpanel({
   *    user:   { email: "mix@pan.el",... },
   *    token:  "mixpanel-token"
   *  });
   */  

  cdb.admin.Mixpanel = cdb.core.Model.extend({

    initialize: function(opts) {
      this._setMixpanel(opts.token);
      this._setUser(opts.user);
      this.bindEvents();
    },

    _setMixpanel: function(token) {
      mixpanel.init(token);
    },

    _setUser: function(user_data) {
      mixpanel.identify(user_data.username);
      mixpanel.name_tag(user_data.username);
      mixpanel.people.set({
        'id':                  user_data.id,
        '$email':              user_data.email,
        'username':            user_data.username,
        'account_type':        user_data.account_type,
        'table_count':         user_data.table_count,
        'visualization_count': user_data.visualization_count,
        'failed_import_count': user_data.failed_import_count
      });
    },

    bindEvents: function() {
      cdb.god.bind("mixpanel", this._setTrack, this);
    },

    _setTrack: function(msg, obj) {
      mixpanel.track(msg, obj)
    }
  });
