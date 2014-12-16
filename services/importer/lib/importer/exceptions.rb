# encoding: utf-8

require_relative '../../../../services/datasources/lib/datasources/exceptions'

module CartoDB
  module Importer2

    # Generic/unmapped errors
    class GenericImportError                    < StandardError; end
    # Mapped errors
    class FileTooBigError                       < StandardError; end
    class InstallError                          < StandardError; end
    class EmptyFileError                        < StandardError; end
    class ExtractionError                       < StandardError; end
    class GeometryCollectionNotSupportedError   < StandardError; end
    class InvalidGeoJSONError                   < StandardError; end
    class InvalidShpError                       < StandardError; end
    class KmlNetworkLinkError                   < StandardError; end
    class InvalidNameError                      < StandardError; end
    class LoadError                             < StandardError; end
    class MissingProjectionError                < StandardError; end
    class ShpNormalizationError                 < StandardError; end
    class StorageQuotaExceededError             < StandardError; end
    class TableQuotaExceededError               < StandardError; end
    class TiffToSqlConversionError              < StandardError; end
    class UnknownError                          < StandardError; end
    class UnknownSridError                      < StandardError; end
    class UnsupportedFormatError                < StandardError; end
    class UploadError                           < StandardError; end
    class DownloadError                         < StandardError; end
    class TooManyNodesError                     < StandardError; end
    class GDriveNotPublicError                  < StandardError; end
    class EncodingDetectionError                < StandardError; end
    class XLSXFormatError                       < StandardError; end
    class MalformedCSVException                 < GenericImportError; end
    class TooManyColumnsError                   < GenericImportError; end

    # @see also app/models/synchronization/member.rb => run() for more error codes
    # @see config/initializers/carto_db.rb For the texts
    ERRORS_MAP = {
      InstallError                          => 0001,
      UploadError                           => 1000,
      DownloadError                         => 1001,
      UnsupportedFormatError                => 1002,
      ExtractionError                       => 1003,
      XLSXFormatError                       => 1004,
      EmptyFileError                        => 1005,
      InvalidShpError                       => 1006,
      TooManyNodesError                     => 1007,
      GDriveNotPublicError                  => 1010,
      InvalidNameError                      => 1014,
      LoadError                             => 2001,
      EncodingDetectionError                => 2002,
      MalformedCSVException                 => 2003,
      TooManyColumnsError                   => 2004,
      InvalidGeoJSONError                   => 3007,
      UnknownSridError                      => 3008,
      ShpNormalizationError                 => 3009,
      MissingProjectionError                => 3101,
      GeometryCollectionNotSupportedError   => 3201,
      KmlNetworkLinkError                   => 3202,
      FileTooBigError                       => 6666,
      StorageQuotaExceededError             => 8001,
      TableQuotaExceededError               => 8002,
      UnknownError                          => 99999,
      CartoDB::Datasources::DatasourceBaseError                   => 1012,
      CartoDB::Datasources::AuthError                             => 1011,
      CartoDB::Datasources::TokenExpiredOrInvalidError            => 1012,
      CartoDB::Datasources::InvalidServiceError                   => 1012,
      CartoDB::Datasources::DataDownloadError                     => 1011,
      CartoDB::Datasources::MissingConfigurationError             => 1012,
      CartoDB::Datasources::UninitializedError                    => 1012,
      CartoDB::Datasources::NoResultsError                        => 1015,
      CartoDB::Datasources::ParameterError                        => 99999,
      CartoDB::Datasources::ServiceDisabledError                  => 99999,
      CartoDB::Datasources::OutOfQuotaError                       => 8001,
      CartoDB::Datasources::InvalidInputDataError                 => 1012,
      CartoDB::Datasources::ResponseError                         => 1011,
      CartoDB::Datasources::ExternalServiceError                  => 1012,
      CartoDB::Datasources::DropboxPermissionError                => 1016
    }
  end # Importer2
end # CartoDB

