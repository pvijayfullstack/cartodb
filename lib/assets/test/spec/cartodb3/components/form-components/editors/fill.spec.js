var $ = require('jquery');
var Backbone = require('backbone');
require('backbone-forms');
Backbone.$ = $;
require('../../../../../../javascripts/cartodb3/components/form-components/editors/base.js');
require('../../../../../../javascripts/cartodb3/components/form-components/editors/fill.js');

describe('components/form-components/editors/fill', function () {
  beforeEach(function () {
    this.model = new Backbone.Model({
      names: 'pepe',
      stroke: {
        size: {
          range: [1, 30],
          attribute: 'the_geom',
          quantification: 'Quantile'
        },
        color: {
          bins: 5,
          range: ['#FFFFFF', '#FABADA', '#00FF00', '#000000', '#99999'],
          attribute: 'name',
          quantification: 'Jenks',
          opacity: 0.5
        }
      },
      fill: {
        size: {
          range: [1, 30],
          attribute: 'the_geom',
          quantification: 'Quantile'
        },
        color: {
          bins: 5,
          range: ['#FFFFFF', '#FABADA', '#00FF00', '#000000', '#99999'],
          attribute: 'name',
          quantification: 'Jenks',
          opacity: 0.5
        }
      }
    });

    this.view = new Backbone.Form.editors.Fill({
      key: 'stroke',
      schema: {
        options: ['column1', 'column2', 'column3']
      },
      model: this.model
    });
    this.view.render();
  });

  it('should render properly', function () {
    expect(this.view.$('.CDB-OptionInput-item').length).toBe(2);
    expect(this.view.$el.text()).toContain('1..30');
  });

  it('should open a fill dialog on click', function () {
    expect(this.view.$('.Editor-boxModal').length).toBe(0);
    this.view.$('.CDB-OptionInput-item:first-child').click();
    expect(this.view.$('.Editor-boxModal').length).toBe(1);
  });

  it('should render the size dialog component ', function () {
    this.view.$('.CDB-OptionInput-item:first-child').click();
    expect(this.view.$('.CDB-NavMenu-item').length).toEqual(2);
    expect(this.view.$('.Editor-boxModal').text()).toContain('form-components.editors.fill.input-number.fixed');
    expect(this.view.$('.Editor-boxModal').text()).toContain('form-components.editors.fill.input-number.value');
    expect(this.view.$('.Editor-boxModal').text()).toContain('Quantile');
    expect(this.view.$('.Editor-boxModal').text()).toContain('the_geom');
  });

  it('should render the color dialog component ', function () {
    this.view.$('.CDB-OptionInput-item:last-child').click();
    expect(this.view.$('.CDB-NavMenu-item').length).toEqual(2);
    expect(this.view.$('.Editor-boxModal').text()).toContain('form-components.editors.fill.input-color.solid');
    expect(this.view.$('.Editor-boxModal').text()).toContain('form-components.editors.fill.input-color.value');
    expect(this.view.$('.Editor-boxModal').text()).toContain('5 form-components.editors.fill.input-ramp.buckets');
    expect(this.view.$('.Editor-boxModal').text()).toContain('name');
    expect(this.view.$('.Editor-boxModal').text()).toContain('Jenks');
  });

  describe('hide panes', function () {
    beforeEach(function () {
      this.view = new Backbone.Form.editors.Fill({
        key: 'fill',
        schema: {
          options: ['column1', 'column2', 'column3'],
          editorAttrs: {
            size: {
              hidePanes: ['fixed']
            },
            color: {
              hidePanes: ['fixed']
            }
          }
        },
        model: this.model
      });
      this.view.render();
    });

    it('should render the size dialog component ', function () {
      this.view.$('.CDB-OptionInput-item:first-child').click();
      expect(this.view.$('.CDB-NavMenu-item').length).toEqual(1);
      expect(this.view.$('.Editor-boxModal').text()).not.toContain('form-components.editors.fill.input-number.fixed');
      expect(this.view.$('.Editor-boxModal').text()).toContain('form-components.editors.fill.input-number.value');
      expect(this.view.$('.Editor-boxModal').text()).toContain('Quantile');
      expect(this.view.$('.Editor-boxModal').text()).toContain('the_geom');
    });

    it('should render the color dialog component', function () {
      this.view.$('.CDB-OptionInput-item:last-child').click();
      expect(this.view.$('.CDB-NavMenu-item').length).toEqual(1);
      expect(this.view.$('.Editor-boxModal').text()).not.toContain('form-components.editors.fill.input-color.solid');
      expect(this.view.$('.Editor-boxModal').text()).toContain('form-components.editors.fill.input-color.value');
      expect(this.view.$('.Editor-boxModal').text()).toContain('5 form-components.editors.fill.input-ramp.buckets');
      expect(this.view.$('.Editor-boxModal').text()).toContain('name');
      expect(this.view.$('.Editor-boxModal').text()).toContain('Jenks');
    });
  });

  afterEach(function () {
    this.view.remove();
  });
});
