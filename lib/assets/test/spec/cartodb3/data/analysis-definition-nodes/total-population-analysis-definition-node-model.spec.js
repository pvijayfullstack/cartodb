var AnalysisDefinitionNodesCollection = require('../../../../../javascripts/cartodb3/data/analysis-definition-nodes-collection');

describe('data/analysis-definition-nodes/total-population-analysis-definition-node-model', function () {
  beforeEach(function () {
    this.collection = new AnalysisDefinitionNodesCollection();
    this.collection.add({
      type: 'total-population',
      params: {
        column_name: 'col',
        source: {
          id: 'a0',
          type: 'source',
          params: {
            query: 'SELECT * FROM foo_bar'
          }
        }
      }
    });
    this.model = this.collection.get('a1');
  });

  it('should have recovered the source analysis to a model too', function () {
    expect(this.collection.length).toEqual(2);
    expect(this.collection.first().id).toEqual('a0');
    expect(this.collection.last().id).toEqual('a1');
  });

  it('should have reference to the source', function () {
    expect(this.model.get('source_id')).toEqual('a0');
  });

  it('should flattened the data', function () {
    expect(this.model.attributes).toEqual({
      id: 'a1',
      type: 'total-population',
      column_name: 'col',
      source_id: 'a0'
    });
  });

  describe('.toJSON', function () {
    it('should return serialized object', function () {
      expect(this.model.toJSON()).toEqual({
        id: 'a1',
        type: 'total-population',
        params: {
          column_name: 'col',
          source: {
            id: 'a0',
            type: 'source',
            params: {
              query: 'SELECT * FROM foo_bar'
            }
          }
        }
      });
    });
  });
});
