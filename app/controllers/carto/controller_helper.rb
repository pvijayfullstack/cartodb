require_dependency 'carto/uuidhelper'

module Carto
  class CartoError < StandardError
    attr_reader :message, :status

    def initialize(message, status)
      @message = message
      @status = status
    end
  end

  class UUIDParameterFormatError < CartoError
    def initialize(parameter, status = 400)
      super("Parameter not UUID format: #{parameter}", status)
    end
  end

  class UnauthorizedError < CartoError
    def initialize(message = "You don't have permission to access that resource", status = 403)
      super(message, status)
    end
  end

  class LoadError < CartoError
    def initialize(message, status = 404)
      super(message, status)
    end
  end

  module ControllerHelper
    include Carto::UUIDHelper

    def uuid_parameter(parameter)
      param = params[parameter]
      if is_uuid?(param)
        param
      else
        raise Carto::UUIDParameterFormatError.new(parameter)
      end
    end

    def rescue_from_carto_error(error)
      message = error.message
      status = error.status

      respond_to do |format|
        format.html { render text: message, status: status }
        format.json { render json: { errors: message }, status: status }
      end
    end
  end
end
