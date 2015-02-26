var CreateScratch = require('./imports/create_scratch_view');
var ImportService = require('./imports/service_import/import_service_view');
var ImportTwitter = require('./imports/twitter_import/import_twitter_view');
var ImportDataView = require('./imports/import_data_view');
var ImportArcGISView = require('./imports/import_arcgis_view');

/**
 * Attributes:
 *
 *  className: import pane class view
 *  fallbackClassName: ...
 *  name: local name
 *  title: text for tab link
 *  options:
 *    - service:
 *    - fileExtensions:
 *    - showAvailableFormats:
 *    - acceptSync:
 *    - fileAttrs:
 *
 */

module.exports = {
  File: {
    className: ImportDataView,
    name: 'file',
    title: 'Data file',
    options: {
      type: 'url',
      fileEnabled: true,
      acceptSync: true
    }
  },
  GDrive:   {
    className: ImportService,
    name: 'gdrive',
    title: 'Google Drive',
    options: {
      service: 'gdrive',
      fileExtensions: ['Google SpreadSheet', 'CSV'],
      showAvailableFormats: false,
      acceptSync: true,
      fileAttrs: {
        ext: true,
        title: 'filename',
        description: {
          content: [{
            name: 'size',
            format: 'size',
            key: true
          }]
        }
      }
    }
  },
  Dropbox: {
    className: ImportService,
    name: 'dropbox',
    title: 'Dropbox',
    options: {
      service: 'dropbox',
      fileExtensions: ['CSV', 'XLS', 'KML', 'GPX'],
      showAvailableFormats: true,
      acceptSync: true,
      fileAttrs: {
        ext: true,
        title: 'filename',
        description: {
          content: [
            {
              name: 'id',
              format: ''
            },
            {
              name: 'size',
              format: 'size',
              key: true
            }
          ],
          separator: '-'
        }
      }
    }
  },
  Twitter: {
    className: ImportTwitter,
    fallback: 'new_common/views/create/listing/import_twitter_fallback',
    name: 'twitter',
    title: 'Twitter'
  },
  Scratch: {
    className: CreateScratch,
    name: 'scratch',
    title: 'Empty dataset'
  },
  Arcgis: {
    className: ImportArcGISView,
    fallback: 'new_common/views/create/listing/import_arcgis_fallback',
    name: 'arcgis',
    title: 'ArcGIS online'
  },
  Salesforce: {
    className: ImportDataView,
    fallback: 'new_common/views/create/listing/import_salesforce_fallback',
    name: 'salesforce',
    title: 'SalesForce',
    options: {
      type: 'service',
      service_name: 'salesforce',
      acceptSync: true,
      formTemplate: 'new_common/views/create/listing/import_types/data_form_salesforce',
      headerTemplate: 'new_common/views/create/listing/import_types/data_header_salesforce'
    }
  },
  Mailchimp: {
    className: ImportService,
    fallback: 'new_common/views/create/listing/import_mailchimp_fallback',
    name: 'mailchimp',
    title: 'MailChimp',
    options: {
      service: 'mailchimp',
      fileExtensions: [],
      acceptSync: true,
      showAvailableFormats: false,
      fileAttrs: {
        ext: true,
        title: 'filename',
        description: {
          content: [{
            name: 'member_count',
            format: 'number',
            key: true
          }],
          itemName: 'member',
          separator: ''
        }
      }
    }
  }
};
