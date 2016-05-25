var cdb = require('cartodb.js');
var _ = require('underscore');

var EditionTogglePanelView = require('../../../../components/edition-toggle/edition-toggle-panel-view');
var CodeMirrorView = require('../../../../components/code-mirror/code-mirror-view');
var InfowindowContentView = require('./infowindow-content-view');
var ScrollView = require('../../../../components/scroll/scroll-view');

module.exports = cdb.core.View.extend({
  initialize: function (opts) {
    this._initTemplates();
  },

  render: function () {
    this.clearSubViews();

    var self = this;

    // CodeMirror placeholder
    var CodeMirrorModel = new cdb.core.Model({
      content: 'Hola mundo'
    });

    var Dummy = cdb.core.View.extend({
      render: function () {
        this.$el.html(this.options.content);
        return this;
      }
    });

    var tabPaneTabs = [{
      label: self.options.toggleLabels.off,
      selected: true,
      createContentView: function () {
        return new ScrollView({
          createContentView: function () {
            return new InfowindowContentView(_.extend(self.options, { templates: self._templates }));
          }
        });
      },
      createControlView: function () {
        return new Dummy({
          content: 'Button'
        });
      }
    }, {
      label: self.options.toggleLabels.on,
      selected: false,
      createContentView: function () {
        return new ScrollView({
          createContentView: function () {
            return new CodeMirrorView({
              model: CodeMirrorModel
            });
          }
        });
      },
      createControlView: function () {
        return new Dummy({
          content: 'Undo'
        });
      }
    }];

    var editionTogglePanelView = new EditionTogglePanelView({
      className: 'Editor-content',
      panes: tabPaneTabs
    });

    this.$el.append(editionTogglePanelView.render().el);
    this.addView(editionTogglePanelView);

    return this;
  }
});
