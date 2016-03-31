var _ = require('underscore');
var camshaftReference = require('../../../data/camshaft-reference');
var nodeIds = require('../../../data/analysis-definition-node-ids');
var AddAnalysisOptionModel = require('./add-analysis-option-model');

var defaultDisabledOptionDesc = function (inputGeometryType, requiredInputGeometries) {
  return _t('components.modals.add-analysis.disabled-option-desc', {
    inputGeometryType: inputGeometryType,
    requiredInputGeometries: requiredInputGeometries.join(', ')
  });
};

/**
 * @param {String} inputGeometryType e.g. 'point', 'polygon', 'line', …
 * @param {Object} analysisDefinitionNodeModel
 * @return {Array} of Backbone models, each representing an analysis type
 */
module.exports = function (inputGeometryType, analysisDefinitionNodeModel) {
  var models = [];

  var sourceId = analysisDefinitionNodeModel.id;
  var id = nodeIds.next(sourceId);
  var areaOfInfluence = _t('components.modals.add-analysis.option-sub-titles.area-of-influence');

  var type = 'buffer';
  var validGeometries = camshaftReference.getValidInputGeometriesForType(type);
  var isEnabled = _.contains(validGeometries, inputGeometryType);
  models.push(
    new AddAnalysisOptionModel({
      title: _t('components.modals.add-analysis.option-types.buffer.title'),
      sub_title: areaOfInfluence,
      desc: isEnabled
        ? _t('components.modals.add-analysis.option-types.buffer.desc')
        : defaultDisabledOptionDesc(inputGeometryType, validGeometries),
      enabled: isEnabled,
      node_attrs: {
        id: id,
        type: type,
        source_id: sourceId,
        radio: 300
      }
    })
  );

  type = 'trade-area';
  validGeometries = camshaftReference.getValidInputGeometriesForType(type);
  isEnabled = _.contains(validGeometries, inputGeometryType);
  models.push(
    new AddAnalysisOptionModel({
      title: _t('components.modals.add-analysis.option-types.trade-area.title'),
      sub_title: areaOfInfluence,
      desc: isEnabled
        ? _t('components.modals.add-analysis.option-types.trade-area.desc')
        : defaultDisabledOptionDesc(inputGeometryType, validGeometries),
      enabled: isEnabled,
      node_attrs: {
        id: id,
        type: type,
        source_id: sourceId,
        kind: 'drive',
        time: 300
      }
    })
  );

  return models;
};
