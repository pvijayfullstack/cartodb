cdb.open.LikeView = cdb.core.View.extend({

  events: {
    "click": "_onClick"
  },

  _onClick: function(e) {

    e.preventDefault();
    e.stopPropagation();

    this.model.toggleLiked();

    var self = this;

    this.model.bind("error", function(response) {

      if (response.status === 400) { // if the item was already liked, we "fake" the like
        self.model.set({ id: self.model.get("vis_id"), liked: true });
      } else if (response.status === 403) {
        window.top.location.href = "https://cartodb.com/sessions/new";
      }
    });

  },

  initialize: function() {

    this.model.bind("change:likes, change:liked", function() {

      $(".js-like .counter").text(this.model.get("likes"));

      if (this.model.get("liked")) {

        this._highlightHeart();

      } else {

        this._unhighlightHeart();
      }

    }, this);

    if (this.options.auto_fetch) this.model.fetch();

  },

  _unhighlightHeart: function() {

    var $button  = $(".js-like");
    var $icon    = $(".js-like .icon");
    var $counter = $(".js-like .counter");

    $icon.addClass("is-pulsating is-animated");
    $icon.one('webkitAnimationEnd mozAnimationEnd MSAnimationEnd oanimationend animationend', function() {
      $(this).removeClass("is-pulsating is-animated");
      $button.removeClass("is-highlighted");
    });

  },

  _highlightHeart: function() {

    var $button  = $(".js-like");
    var $icon    = $(".js-like .icon");
    var $counter = $(".js-like .counter");

    $button.addClass("is-highlighted");
    $icon.addClass("is-pulsating is-animated");
    $icon.one('webkitAnimationEnd mozAnimationEnd MSAnimationEnd oanimationend animationend', function() {
      $(this).removeClass("is-pulsating is-animated");
    });
  }


});

cdb.open.Like = cdb.admin.Like.extend({
});
