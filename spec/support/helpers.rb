#encoding: UTF-8
module HelperMethods

  def prepare_oauth_request(consumer, url, options={})
    url = URI.parse(url)
    http = Net::HTTP.new(url.host, url.port)
    if options[:form_data]
      req = Net::HTTP::Post.new(url.request_uri)
      req.set_form_data(options[:form_data])
    else
      req = Net::HTTP::Get.new(url.request_uri)
    end
    req.oauth!(http, consumer, options[:token])
    req
  end

  def upload_file(file_path, mime_type)
    file = Rack::Test::UploadedFile.new(Rails.root.join(file_path), mime_type)
  end

  def serve_file(file_path, options = {})
    require 'webrick'
    server = WEBrick::HTTPServer.new(
      :AccessLog       => [],
      :Logger          => WEBrick::Log::new("/dev/null", 7), #comment this line if weird things happen
      :Port            => 9999,
      :DocumentRoot    => File.dirname(file_path),
      :RequestCallback => Proc.new() { |req, res|
        options[:headers].each { |k, v| res[k] = v } if options[:headers].present?
        if options[:headers].present? && options[:headers]['content-type'].present?
          res.content_type = options[:headers]['content-type']
        end
      }
    )

    trap("INT"){ server.shutdown }

    Thread.new { server.start }

    yield "http://localhost:9999/#{File.basename(file_path)}" if block_given?

    Thread.new { server.shutdown }
  end
end
