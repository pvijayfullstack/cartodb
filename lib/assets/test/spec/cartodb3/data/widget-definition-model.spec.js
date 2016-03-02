var ConfigModel = require('../../../../javascripts/cartodb3/data/config-model');
var WidgetDefinitionModel = require('../../../../javascripts/cartodb3/data/widget-definition-model');

describe('data/widget-definition-model', function () {
  beforeEach(function () {
    var configModel = new ConfigModel({
      base_url: '/u/pepe'
    });
    this.widgetDefModel = new WidgetDefinitionModel({
      id: 'w-456',
      title: 'some title',
      type: 'formula',
      layer_id: 'l-1',
      options: {
        column: 'hello',
        operation: 'avg'
      }
    }, {
      parse: true,
      configModel: configModel,
      mapId: 'm-123'
    });
  });

  it('should have a url pointing to layers API endpoint', function () {
    expect(this.widgetDefModel.url()).toEqual('/u/pepe/api/v3/maps/m-123/layers/l-1/widgets/w-456');

    // when no id:
    this.widgetDefModel.set('id', null);
    expect(this.widgetDefModel.url()).toEqual('/u/pepe/api/v3/maps/m-123/layers/l-1/widgets');
  });

  it('should flatten the structure on parse', function () {
    expect(this.widgetDefModel.get('column')).toEqual('hello');
  });

  it('should set some defaults', function () {
    expect(this.widgetDefModel.get('sync_on_data_change')).toBe(true);
    expect(this.widgetDefModel.get('sync_on_bbox_change')).toBe(true);
  });

  describe('.toJSON', function () {
    beforeEach(function () {
      this.d = this.widgetDefModel.toJSON();
    });

    it('should include expected attrs', function () {
      expect(this.d).toEqual(jasmine.objectContaining({ id: 'w-456' }));
      expect(this.d).toEqual(jasmine.objectContaining({ type: 'formula' }));
      expect(this.d).toEqual(jasmine.objectContaining({ title: 'some title' }));
      expect(this.d).toEqual(jasmine.objectContaining({ layer_id: 'l-1' }));
      expect(this.d).not.toContain('column');
      expect(this.d).not.toContain('operation');
    });

    it('should provide non-default attrs as options', function () {
      expect(this.d.options).toEqual(jasmine.objectContaining({ column: 'hello' }));
      expect(this.d.options).toEqual(jasmine.objectContaining({ operation: 'avg' }));
    });
  });
});
