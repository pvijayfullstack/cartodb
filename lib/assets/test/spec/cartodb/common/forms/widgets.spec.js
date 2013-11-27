
describe('Form', function() {
  var view;
  beforeEach(function() {
    var simple_form = [
      {
         name: 'Marker Fill',
         form: {
           'polygon-fill': {
                 type: 'color' ,
                 value: '#00FF00'
            },
            'polygon-opacity': {
                 type: 'opacity' ,
                 value: 0.6
            }
        }
      },
      {
         name: 'test',
         form: {
           'polygon-fill': {
                 type: 'color' ,
                 value: '#00FF00'
            },
            'polygon-opacity': {
                 type: 'opacity' ,
                 value: 0.6
            }
        }
      }
    ];
    view = new cdb.forms.Form({
      form_data: simple_form,
      model: new Backbone.Model()
    });


  });

  it('should render form fields', function() {
    view.render();
    expect(view.$('li').length).toEqual(2);
    expect(view.$('.form_color').length).toEqual(2);
    expect(view.$('.form_spinner').length).toEqual(2);
    expect(_.keys(view._subviews).length).toEqual(4);
    view.render();
    expect(view.$('li').length).toEqual(2);
  });

  it('should has a model with properties', function() {
    view.render();
    expect(view.model.get('polygon-fill')).toEqual('#00FF00');
    expect(view.model.get('polygon-opacity')).toEqual(0.6);
  });

  it("should clear fields when render", function() {
    view.render();
    var v = view._subviews[_.keys(view._subviews)[0]];
    expect(v._parent).toEqual(view);
    view.render();
    expect(v._parent).toEqual(null);
  });

  it("should get fields by name", function() {
    view.render();
    var v = view.getFieldsByName('Marker Fill');
    expect(v.length).toEqual(2);
    expect(v[0].options.field_name).toEqual('Marker Fill');
    expect(v[0].options.property).toEqual('polygon-fill');
    expect(v[1].options.field_name).toEqual('Marker Fill');
  });

});

describe('widgets', function() {

  describe('cdb.forms.Color', function() {
    var view, model;
    beforeEach(function() {
      model = new Backbone.Model({ 'test': '#FFF'});
      view = new cdb.forms.Color({ model: model, property: 'test' });
    });

    it("should render", function() {
      view.render();
      expect(view.$('.color').css('background-color')).toEqual('rgb(255, 255, 255)');
    });

    it("should render color", function() {
      model.set({ test: '#000' });
      expect(view.$('.color').css('background-color')).toEqual('rgb(0, 0, 0)');
    });

    it("should use image_property", function() {
      model = new Backbone.Model({ 'test': '#FaF'});
      view = new cdb.forms.Color({ model: model, property: 'test', extra: {
        image_property: 'polygon-pattern-file'
      }});
      view._initPicker();
      view.color_picker.trigger('fileChosen', 'myurl.png');
      expect(model.get('polygon-pattern-file')).toEqual('url(myurl.png)')
      expect(model.get('test')).toEqual(undefined);

      view._initPicker();
      view.color_picker.trigger('colorChosen', '#FFa');
      expect(model.get('polygon-pattern-file')).toEqual(undefined);
      expect(model.get('test')).toEqual('#FFa');

    })

  });

  describe('cdb.forms.OpacityPolygon', function() {
    var view, model;
    beforeEach(function() {
      model = new Backbone.Model({ 'test': 2 });
      view = new cdb.forms.OpacityPolygon({ el: $('<div>'),
        model: model,
        property: 'test',
        min: 0,
        max: 10
      });
    });

    it("should swicth property depending other one", function() {
      view.switchProperty();
      expect(model.get('test')).toEqual(2);
      model.set('polygon-pattern-file', 'url(test.png)');
      expect(model.get('test')).toEqual(undefined);
      expect(model.get('polygon-pattern-opacity')).toEqual(2);

      expect(model.originalProperty, 'test');
      model.set('polygon-pattern-file', 'url(test2.png)');
      expect(model.originalProperty, 'test');

      model.unset('polygon-pattern-file');
      expect(model.get('test')).toEqual(2);
    });

  });

  describe('cdb.forms.Spinner', function() {
    var view, model;
    beforeEach(function() {
      model = new Backbone.Model({ 'test': 0});
      view = new cdb.forms.Spinner({ el: $('<div>'),
        model: model,
        property: 'test',
        min: 0,
        max: 10
      });
    });

    it("should render", function() {
      view.render();
      expect(view.$('.value').val()).toEqual('0');
    });

    it("should render color", function() {
      model.set({ test: 1 });
      expect(view.$('.value').val()).toEqual('1');
    });

    it("should increment/decrement value on click", function() {
      view.render();
      view.$('.plus').trigger('click');
      expect(view.$('.value').val()).toEqual('1');
      expect(model.get('test')).toEqual(1);
      view.$('.minus').trigger('click');
      expect(view.$('.value').val()).toEqual('0');
      expect(model.get('test')).toEqual(0);
    });

    it("should not pass max/min", function() {
      model.set({ test: 9.1 });
      view.options.max = 10;
      view.$('.plus').trigger('click');
      expect(view.$('.value').val()).toEqual('10');

      model.set({ test: 0.1 });
      view.options.min = 0;
      view.$('.minus').trigger('click');
      expect(view.$('.value').val()).toEqual('0');
    });

    it("should increment the value specified", function() {
      model.set({ test: 9.1 });
      view.options.inc = 0.1;
      view.$('.plus').trigger('click');
      expect(view.$('.value').val()).toEqual('9.2');
    });

    it("should change when slider changes", function() {
      view.render();
      view.spinner_slider.trigger('valueSet', 0.55);
      expect(model.get('test')).toEqual(0.55);
    });
  });

  describe('cdb.forms.Combo', function() {
    var spy, view, model, data;

    beforeEach(function() {

      model = new Backbone.Model({ hola: 10, test: 1 });
      data = [[ "field1", "one" ], [ "field2", "two" ], [ "field3", "three" ], [ "field4", "four" ]];

      spy = spyOn(cdb.forms.Combo.prototype, '_onUpdate');

      view = new cdb.forms.Combo({
        width: "123px",
        model: model,
        extra: data,
        property: 'test'
      });

    });

    it("should render", function() {
      view.render();
      expect(view.$('option').length).toEqual(4);
    });

    it("should be able to initialize with values", function() {
      view = new cdb.forms.Combo({
        model: model,
        property: 'test',
        extra: [['one', 1], ['two', 2]]
      });
      view.render();
      view.$('select').val(2).change();
      expect(model.get('test')).toEqual('2');
    });

    it("should generate a string of options", function() {
      var options = view._getOptions();
      expect(options).toEqual('<option value="one">field1</option><option value="two">field2</option><option value="three">field3</option><option value="four">field4</option>');
    });

    it("should generate a string of options if the combo has a placeholder", function() {
      view.options.placeholder = "Hi";
      var options = view._getOptions();
      expect(options).toEqual('<option></option><option value="one">field1</option><option value="two">field2</option><option value="three">field3</option><option value="four">field4</option>');
    });

    it("when val changes it should update model", function() {
      view.render();
      view.$('select').val('four').change();
      expect(model.get('test')).toEqual('four');
    });

    it("should render when model changed", function() {
      view.render();
      model.set({'test': 'one'});
      expect(view.$('select').val()).toEqual('one');
    });

    it("should throw an event when the observed field changes", function() {
      view.render();
      model.set('test', 2);
      expect(spy).toHaveBeenCalled();
    });

    it("should throw an event when the data change", function() {
      view.render();
      view.updateData([[ "field1", "one" ], [ "field2", "two" ]]);
      expect(spy).toHaveBeenCalled();
    });

    it("shouldn't throw an event when a field changes", function() {
      view.render();
      model.set('hola', 2);
      expect(spy).not.toHaveBeenCalled();
      expect(view.$('select').val()).toEqual('one');
    });

    it("should be able to initialize with values", function() {
      view.render();
      view.$('select').val("two").change();
      expect(model.get('test')).toEqual('two');
    });

    it("should be able to deselect the selected value if the select has a placeholder", function() {
      view.options.placeholder = "Hi";
      view.render();
      view.$('select').val("four").change();

      view.deselect();

      expect(model.get('test')).toEqual('');
      expect(view.$('select').val()).toEqual('');

    });

    it("shouldn't be able to deselect the selected value if the select doesn't have a placeholder", function() {
      view.render();
      view.$('select').val("four").change();

      view.deselect();

      // Withouth placeholder we select the first item
      expect(model.get('test')).toEqual('one');
      expect(view.$('select').val()).toEqual('one');

    });

    it("should be able to specify the width", function() {
      view.render();
      var width = view.$('select').css("width");
      expect(width).toEqual('123px');
    });

    it("should be able to format results of the dropdown", function() {
      spyOn(view, '_formatResult');
      view.options.formatResult = true;
      var $body = $('<body>');
      $body.append(view.render().el);
      view.$('select').select2("open");
      
      waits(100);

      runs(function() {
        expect(view._formatResult).toHaveBeenCalled();
        $body.remove();
      })
    });

  });

  describe('cdb.forms.Switch', function() {
    var view, model;
    beforeEach(function() {
      model = new Backbone.Model({ 'test': true });
      view = new cdb.forms.Switch({
        el: $('<a>'),
        model: model,
        property: 'test'
      });
    });

    it("should render", function() {
      view.render();
      expect(view.$el.hasClass('enabled')).toEqual(true);
    });

    it("should render when model changed", function() {
      view.render();
      model.set({'test': false});
      expect(view.$el.hasClass('enabled')).toEqual(false);
      expect(view.$el.hasClass('disabled')).toEqual(true);
    });

    it("when val changes it should update model", function() {
      view.render();
      view.$el.trigger('click');
      expect(model.get('test')).toEqual(false);
    });
  });


});
