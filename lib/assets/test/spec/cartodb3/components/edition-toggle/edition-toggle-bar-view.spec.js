var $ = require('jquery');
var Backbone = require('backbone');
Backbone.$ = $;
var EditionTogglerPanelView = require('../../../../../javascripts/cartodb3/components/edition-toggle/edition-toggle-bar-view.js');
var TabPaneCollection = require('../../../../../javascripts/cartodb3/components/tab-pane/tab-pane-collection');

describe('components/edition-toggle/edition-toggle-bar-view', function () {
  var Dummy = cdb.core.View.extend({
    render: function () {
      this.$el.html(this.options.content);
      return this;
    }
  });

  var panes = [{
    label: 'foo',
    selected: true,
    createContentView: function () {
      return new Dummy({
        content: 'foo'
      });
    }
  }, {
    label: 'bar',
    selected: false,
    createContentView: function () {
      return new Dummy({
        content: 'bar'
      });
    }
  }];

  var controlsView = new Dummy({
    content: 'Button'
  });

  var collection = new TabPaneCollection(panes);

  beforeEach(function () {
    this.view = new EditionTogglerPanelView({
      collection: collection,
      controlsView: controlsView
    });
    this.view.render();
  });

  it('should render properly', function () {
    expect(this.view.$('.js-control').length).toBe(1);
    expect(this.view.$('.js-actions').length).toBe(1);
    expect(this.view.$('.js-actions').html()).toContain('Button');
  });

  afterEach(function () {
    this.view.clean();
  });
});
