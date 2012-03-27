# coding: UTF-8
module CartoDB
  class Importer
    class << self
      attr_accessor :debug
    end
    
    include CartoDB::Import::Util
    
    @@debug = true
    RESERVED_COLUMN_NAMES = %W{ oid tableoid xmin cmin xmax cmax ctid }
    SUPPORTED_FORMATS     = %W{ .csv .shp .ods .xls .xlsx .tif .tiff .kml .kmz .js .json .tar .gz .tgz .osm .bz2 }
    
    attr_accessor :import_from_file,              
                  :db_configuration, 
                  :db_connection, 
                  :append_to_table,
                  :suggested_name,                      
                  :ext                   
    attr_reader   :table_created, 
                  :force_name
    
    # Initialiser has to get the file in a standard location on the filesystem    
    def initialize(options = {})
      @entries          = []
      @python_bin_path  = `which python`.strip
      @psql_bin_path    = `which psql`.strip   
      @runlog           = OpenStruct.new :log => [], :stdout => [], :err => []   
      @@debug           = options[:debug]
      @data_import      = DataImport.find(:id=>options[:data_import_id])
      @data_import_id   = options[:data_import_id]
      @append_to_table  = options[:append_to_table] || nil
      @db_configuration = options.slice :database, :username, :password, :host, :port
      @db_configuration = {:port => 5432, :host => '127.0.0.1'}.merge @db_configuration
      @db_connection = Sequel.connect("postgres://#{@db_configuration[:username]}:#{@db_configuration[:password]}@#{@db_configuration[:host]}:#{@db_configuration[:port]}/#{@db_configuration[:database]}")      

      # Setup candidate file
      @import_from_file = options[:import_from_file]
      if options[:import_from_url]        
        begin
          @import_from_file = temporary_filename() + File.basename(options[:import_from_url])                
          `wget \"#{options[:import_from_url]}\" -O #{@import_from_file}`
        rescue => e
          log e
          raise e
        end    
      end      
      raise "import_from_file value can't be nil" unless @import_from_file
      
      # Setup suggested name  
      if options[:suggested_name]
        @force_name     = true
        @suggested_name = get_valid_name(options[:suggested_name])
      else
        @force_name = false
      end
      
      # TODO: Explain THIS!
      if @import_from_file.is_a?(String) 
        @filesrc = nil
        @fromuri = false
        if @import_from_file =~ /^http/ # Tells us it is a URL
          # KML from FusionTables urls were not coming with extensions
          if @import_from_file =~ /fusiontables/
            @filesrc = "fusiontables"
          end
          @fromuri = true
          #@import_from_file = URI.escape(@import_from_file) # Ensures open-uri will work
        end
          begin
            open(URI.escape(@import_from_file)) do |res| # opens file normally, or open-uri to download/open
              @data_import.file_ready
              file_name = File.basename(@import_from_file)
              @ext = File.extname(file_name)
              # Fix for extensionless fusiontables files
              if @ext == "" 
                if @filesrc == "fusiontables"
                  @ext = ".kml"
                else
                  @ext = ".csv"
                end
              end
              @suggested_name ||= get_valid_name(File.basename(@import_from_file, @ext).downcase.sanitize)
              @import_from_file = Tempfile.new([@suggested_name, @ext])
              @import_from_file.write res.read.force_encoding("UTF-8")
              @import_from_file.close
            end
          rescue e
            if @import_from_file =~ /^http/
              uri = $!.uri
              retry
            else
              @data_import.log_error(e)
            end
          end
        
      else
        original_filename = if @import_from_file.respond_to?(:original_filename)
          @import_from_file.original_filename
        else
          @import_from_file.path
        end
        @ext = File.extname(original_filename)
        @suggested_name ||= get_valid_name(File.basename(original_filename,@ext).tr('.','_').downcase.sanitize)
      end
      
      # finally setup current path
      @path = @import_from_file.respond_to?(:tempfile) ? @import_from_file.tempfile.path : @import_from_file.path
      @data_import.file_ready
    rescue => e
      @data_import.log_error(e)
      log e.inspect
      raise e
    end
        
    # core import method    
    #
    # Has 3 expansion points
    #
    # * decompression (eg zip, gzip, bz)
    # * preprocessing (transpose data into a format recognised by loader, eg. gpx)
    # * loader (loads the data into postgres, eg csv, shp)
    #
    def import!
      begin
        
        # decompress data and update self with results
        decompressor = CartoDB::Import::Decompressor.create(@ext, self.to_import_hash) 
        @data_import.log_update('file unzipped') if decompressor
        update_self decompressor.process! if decompressor
        @data_import.reload
        
        # TODO: should this be here...?
        @import_type = @ext        
        
        @data_import.log_update("file type set to #{@ext}") 
      
        # Preprocess data and update self with results
        # preprocessors are expected to return a hash datastructure
        preproc = CartoDB::Import::Preprocessor.create(@ext, self.to_import_hash)
        @data_import.reload
        @data_import.log_update('file preprocessed') if preproc
        update_self preproc.process! if preproc
      
        # Load data in
        loader = CartoDB::Import::Loader.create(@ext, self.to_import_hash)
        @data_import.reload
        if !loader
          @data_import.log_update("no importer for this type of data, #{@ext}")
          @data_import.set_error_code(1002)
          raise "no importer for this type of data"          
        end
        @data_import.log_update("file successfully loaded") if loader
        
        i_res, payload = loader.process! 
        @data_import.log_update("file successfully imported")
        
        update_self i_res if i_res
        
        @data_import.save
        return payload
      rescue => e
        @data_import.reload #reload incase errors were written
        #@data_import.log_error(e)
        log "====================="
        log e
        log e.backtrace
        log "====================="
        begin  # TODO: Do we really mean nil here? What if a table is created?
          @db_connection.drop_table @suggested_name
        rescue # silent try to drop the table            
        end
        
        raise e
      ensure
        @db_connection.disconnect
        if @import_from_file.is_a?(File) && File.file?(@import_from_file.path)
          File.unlink(@import_from_file)
        elsif @import_from_file.is_a? Tempfile
          @import_from_file.unlink
        end
        if @data_import
          @data_import.save
        end
      end        
    end  
  end
end