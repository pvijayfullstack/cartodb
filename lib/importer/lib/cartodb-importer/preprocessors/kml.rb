module CartoDB
  module Import
    class KML < CartoDB::Import::Preprocessor

      register_preprocessor :kml
      register_preprocessor :kmz
      register_preprocessor :json
      register_preprocessor :geojson      
      register_preprocessor :js            

      def process!    
        @data_import = DataImport.find(:id=>@data_import_id)
        # run Chardet + Iconv
        fix_encoding 
        
        ogr2ogr_bin_path = `which ogr2ogr`.strip
        ogr2ogr_command = %Q{#{ogr2ogr_bin_path} --config SHAPE_ENCODING LATIN1 -f "ESRI Shapefile" #{@path}.shp #{@path}}
        out = `#{ogr2ogr_command}`
        stdin,  stdout, stderr = Open3.popen3(ogr2ogr_command) 
  
        unless (err = stderr.read).empty?
          @data_import.set_error_code(7)
          @data_import.log_error(err)
          @data_import.log_error("ERROR: failed to convert #{@ext.sub('.','')} to shp")
          raise "failed to convert #{@ext.sub('.','')} to shp"
        end
        
        unless (reg = stdout.read).empty?
          @runlog.stdout << reg
        end

        if File.file?("#{@path}.shp")
          @path = "#{@path}.shp"
          @ext = '.shp'
        else
          @data_import.log_error("ERROR: failed to convert #{@ext.sub('.','')} to shp")
          @runlog.err << "failed to create shp file from #{@ext.sub('.','')}"
        end
            
       # construct return variables
       to_import_hash       
      end  
    end
  end    
end