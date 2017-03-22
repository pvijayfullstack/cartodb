var _ = require('underscore');
var Backbone = require('backbone');
var CoreView = require('backbone/core-view');
var template = require('./analysis-controls.tpl');
var InfoboxView = require('../../../../components/infobox/infobox-view');
var InfoboxFactory = require('../../../../components/infobox/infobox-factory');
var InfoboxModel = require('../../../../components/infobox/infobox-model');
var InfoboxCollection = require('../../../../components/infobox/infobox-collection');
var AnalysesQuotaPresenter = require('./analyses-quota/analyses-quota-presenter');
var AnalysesQuotaOptions = require('./analyses-quota/analyses-quota-options');
var AnalysesQuotaProvider = require('./analyses-quota/analyses-quota-provider');
var AnalysesQuotaEstimation = require('./analyses-quota/analyses-quota-estimation-input');
var AnalysesQuotaEnough = require('./analyses-quota/analyses-quota-enough');
var checkAndBuildOpts = require('../../../../helpers/required-opts');

var REQUIRED_OPTS = [
  'formModel',
  'userActions',
  'userModel',
  'stackLayoutModel',
  'configModel',
  'querySchemaModel',
  'quotaInfo'
];

/**
 * View representing the apply button for a form
 */
module.exports = CoreView.extend({
  className: 'Options-bar Options-bar--right u-flex',

  events: {
    'click .js-save': '_onSaveClicked'
  },

  initialize: function (opts) {
    checkAndBuildOpts(opts, REQUIRED_OPTS, this);
    this._analysisNode = opts.analysisNode;

    AnalysesQuotaEstimation.init(opts.configModel);
    AnalysesQuotaEnough.init(opts.configModel);

    this._viewModel = new Backbone.Model({
      userFetchModelState: this._quotaInfo.getState(),
      isNewAnalysis: !opts.analysisNode,
      hasChanges: !opts.analysisNode
    });

    this._infoboxModel = new InfoboxModel({
      state: this._viewModel.get('userFetchModelState'),
      visible: true
    });

    this._initBinds();

    if (!opts.analysisNode) {
      this._fetchQuotaIfNeeded(function () {
        this._viewModel.set({userFetchModelState: 'fetched'});
        this._infoboxModel.set('state', 'ready');
      }.bind(this));
    }
  },

  render: function () {
    this.clearSubViews();
    var type = this._formModel.get('type');
    var fetchingState = this._viewModel.get('userFetchModelState');
    // If no dataservice, requiresQuota returns false because the model doesn't exist and it's converted to boolean
    var requiresQuota = AnalysesQuotaOptions.requiresQuota(type, this._quotaInfo);
    var html;

    if (this._isAnalysisDone() && !this._hasChanges()) {
      html = this._html();
    } else {
      // If the analysis doesn't require quota, let's not wait or check the fetching state
      if (!requiresQuota) {
        html = this._html();
      } else {
        // If analysis requires quota info, we should wait for the quota info
        if (fetchingState === 'fetching' || fetchingState === 'error') {
          html = this._createQuotaView();
        } else if (fetchingState === 'fetched') {
          if (this._canSave() && requiresQuota) {
            html = this._createQuotaView();
          } else {
            html = this._html();
          }
        }
      }
    }

    this.$el.html(html);
    return this;
  },

  _initBinds: function () {
    this._formModel.on('change', _.debounce(function () {
      this._viewModel.set('hasChanges', true);
      this._fetchQuotaIfNeeded(this.render.bind(this));
    }, 100), this);

    this.add_related_model(this._formModel);

    this._viewModel.on('change:userFetchModelState', function (model, userFetchModelState) {
      this.render();
    }, this);

    this.add_related_model(this._viewModel);

    if (this._analysisNode) {
      this._analysisNode.on('change:status', this.render, this);
      this.add_related_model(this._analysisNode);
    }
  },

  _fetchQuotaIfNeeded: function (notNeededCallback) {
    var type = this._formModel.get('type');
    var isValid = this._formModel.isValid();
    var quota = this._quotaInfo;
    if ((quota.needsCheck() || AnalysesQuotaOptions.requiresQuota(type, quota)) && isValid) {
      this._fetchQuota();
    } else {
      notNeededCallback();
    }
  },

  _fetchQuota: function () {
    this._infoboxModel.set('state', 'fetching');
    this._viewModel.set('userFetchModelState', 'fetching');

    this._quotaInfo.fetch({
      success: function () {
        this._viewModel.set({userFetchModelState: 'fetched'});
      }.bind(this),
      error: function (error) {
        this._viewModel.set({userFetchModelState: 'error', error: error});
        this._infoboxModel.set('state', 'error');
      }.bind(this)
    });
  },

  _html: function () {
    return template({
      label: this._formModel.get('persisted')
        ? _t('editor.layers.analysis-form.apply-btn')
        : _t('editor.layers.analysis-form.create-btn'),
      isDisabled: !this._canSave()
    });
  },

  _createQuotaView: function () {
    var formModel = this._formModel;
    var infoboxModel = this._infoboxModel;
    var viewModel = this._viewModel;
    var type = formModel.get('type');
    var userModel = this._userModel;
    var query = this._querySchemaModel.get('query');
    var service = AnalysesQuotaOptions.getServiceName(type);
    var quotaData = this._quotaInfo;
    var isFetched = this._viewModel.get('userFetchModelState') === 'fetched';

    var self = this;

    this._payload = {};
    this._payload.type = type;

    var errorCallback = function (error) {
      this._viewModel.set('error', error);
      this._infoboxModel.set('state', 'error');
    }.bind(this);

    var dsReady = quotaData.isReady();

    // Only checks api if analysis belongs to a service with quota
    if (service !== null && isFetched && formModel.isValid() && dsReady) {
      // get the estimation for this analysis
      AnalysesQuotaEstimation.fetch(query)
        .then(function (data) {
          // Apply transformation to the input
          // for example isolines takes tracts in in order to calculate estimation
          var rows = AnalysesQuotaOptions.transformInput(type, data, formModel);
          this._payload.estimation = rows;
          // with the input, we calculate wether the quota is enough
          return AnalysesQuotaEnough.fetch(service, rows);
        }.bind(this), errorCallback)
        .then(function (enoughQuota) {
          var payload = this._payload;
          // then we can get the full set of data
          payload.quotaInfo = AnalysesQuotaProvider(type, userModel, quotaData, enoughQuota);
          payload.creditsLeft = payload.quotaInfo.totalQuota - payload.quotaInfo.usedQuota;
          payload.canRunAnalysis = ((enoughQuota && payload.quotaInfo.totalQuota > 0) ||
                                   (payload.quotaInfo.hardLimit === false && payload.quotaInfo.totalQuota > 0));

          // finally we are ready to show the information
          if (viewModel.get('userFetchModelState') === 'fetched') {
            infoboxModel.set('state', 'ready');
          }
        }.bind(self), errorCallback);
    } else if (!dsReady) {
      errorCallback(_t('editor.layers.analysis-form.quota.quota-dataservice-down'));
    }

    var states = [
      {
        state: 'fetching',
        createContentView: function () {
          return InfoboxFactory.createLoading({
            body: _t('editor.layers.analysis-form.quota.loading')
          });
        }
      },
      {
        state: 'ready',
        createContentView: function () {
          var confirmLabel = _t('editor.layers.analysis-form.confirm-analysis');

          var payload = this._payload;
          var quotaMessage = '';

          if (payload.creditsLeft > 0) {
            quotaMessage = _t('editor.layers.analysis-form.quota.credits-left-message', { smart_count: payload.creditsLeft });
          } else {
            quotaMessage = _t('editor.layers.analysis-form.quota.no-credits-message');
          }
          payload.quotaInfo.quotaMessage = quotaMessage;

          var dataInfobox = _.extend(AnalysesQuotaPresenter.make(payload, this._configModel, this._userModel), {
            title: _t('editor.layers.analysis-form.quota.title'),
            mainAction: {
              label: confirmLabel,
              type: 'primary',
              disabled: !this._canSave() || !payload.canRunAnalysis
            },
            quota: payload.quotaInfo
          });

          return InfoboxFactory.createQuota(dataInfobox);
        }.bind(this),
        mainAction: function () {
          var canRunAnalysis = this._payload.canRunAnalysis;
          if (this._canSave() && canRunAnalysis) {
            this._saveAnalysis();
          }
        }.bind(this),
        closeAction: function () {
          this._stackLayoutModel.prevStep('layers');
        }.bind(this)
      },
      {
        state: 'error',
        createContentView: function () {
          return InfoboxFactory.createWithAction({
            title: _t('editor.layers.analysis-form.quota.title'),
            type: 'error',
            body: _t('editor.layers.analysis-form.quota.quota-fetch-error', {
              error: self._viewModel.get('error')
            }),
            mainAction: {
              label: _t('editor.layers.analysis-form.quota.cancel')
            }
          });
        },
        mainAction: function () {
          this._stackLayoutModel.prevStep('layers');
        }.bind(this)
      }
    ];

    this.view = new InfoboxView({
      className: 'Infobox-wrapper',
      infoboxModel: this._infoboxModel,
      infoboxCollection: new InfoboxCollection(states)
    });

    this.addView(this.view);
    return this.view.render().el;
  },

  _canSave: function () {
    var isAnalysisDone = this._isAnalysisDone();
    var isDone = this._viewModel.get('isNewAnalysis') || isAnalysisDone;
    var hasChanges = this._viewModel.get('hasChanges');
    return this._formModel.isValid() && isDone && hasChanges;
  },

  _onSaveClicked: function () {
    if (this._canSave()) {
      this._saveAnalysis();
    }
  },

  _hasChanges: function () {
    return this._viewModel.get('hasChanges') === true;
  },

  _isAnalysisDone: function () {
    return this._analysisNode && (this._analysisNode.isDone() || this._analysisNode.hasFailed());
  },

  _saveAnalysis: function () {
    this._infoboxModel.set('state', 'idle');
    this._userActions.saveAnalysis(this._formModel);
    this._viewModel.set('hasChanges', false);
    this.render();
  }
});
