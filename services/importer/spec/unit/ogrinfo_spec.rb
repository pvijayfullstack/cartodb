# encoding: utf-8
require_relative '../../lib/importer/ogrinfo'

include CartoDB::Importer2

describe OgrInfo do
  describe '#geometry_type' do
    it 'parses the geometry type as returned by ogrinfo' do
      ogrinfo = ogrinfo_factory('TM_WORLD_BORDERS_SIMPL-0.3.shp', 'TM_WORLD_BORDERS_SIMPL-0.3')
      ogrinfo.geometry_type.should == 'Polygon'
    end
    it 'returns nil if the file could not be opened' do
      ogrinfo = ogrinfo_factory('ThisFileDoesNotExist')
      ogrinfo.geometry_type.should == nil
    end
    it "returns 'None' with a CSV with the_geom (with current version)" do
      ogrinfo = ogrinfo_factory('all.csv')
      ogrinfo.geometry_type.should == 'None'
    end
  end

  describe '#geometry_column' do
    it 'parses and return the geometry_column as returned by ogrinfo' do
      ogrinfo = ogrinfo_factory('route2.gpx', 'track_points')
      ogrinfo.geometry_column.should == nil # there's no geometry column as such in gpx files
    end
    it 'returns nil with a CSV with the_geom (with current version)' do
      ogrinfo = ogrinfo_factory('all.csv')
      ogrinfo.geometry_column.should == nil
    end
  end

  describe '#fields' do
    it 'returns an array of fields contained in a CSV file' do
      ogrinfo = ogrinfo_factory('all.csv')
      ogrinfo.fields.should == %w(
        the_geom fips iso2 iso3 un name area pop2005 region
        subregion lon lat cartodb_id created_at updated_at
      )
    end
    it 'gets an array of fields for other file types' do
      ogrinfo = ogrinfo_factory('route2.gpx', 'track_points')
      ogrinfo.fields.should == %w(
        track_fid track_seg_id track_seg_point_id ele time magvar geoidheight
        name cmt desc src link1_href link1_text link1_type link2_href link2_text
        link2_type sym type fix sat hdop vdop pdop ageofdgpsdata dgpsid
      )
    end
  end

  def ogrinfo_factory(filename, layer=nil)
    CartoDB::Importer2::OgrInfo.new(path_to(filename), layer)
  end

  def path_to(filename)
    File.join(File.dirname(__FILE__), '..', 'fixtures', filename)
  end

end
