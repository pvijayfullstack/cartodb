# encoding: utf-8
require 'rspec'

# Unp includes reference to kml_splitter
require_relative '../../lib/importer/unp'

include CartoDB::Importer2

describe KmlSplitter do
  before do
    @one_layer_filepath       = path_to('one_layer.kml')
    @multiple_layer_filepath  = path_to('multiple_layer.kml')
    @temporary_directory      = '/var/tmp'
  end

  describe '#run' do
    it 'splits a multilayer KML into single-layer KML' do
      source_file = SourceFile.new(@multiple_layer_filepath)
      splitter    = KmlSplitter.new(source_file, @temporary_directory)
      splitter.run
      splitter.source_files.length.should eq 10
    end
  end

  describe '#layers_in' do
    it 'returns all layers name in the file' do
      source_file = SourceFile.new(@one_layer_filepath)
      splitter    = KmlSplitter.new(source_file, @temporary_directory)
      splitter.layers_in(source_file).should eq ["Absolute_and_Relative"]

      source_file = SourceFile.new(@multiple_layer_filepath)
      splitter    = KmlSplitter.new(source_file, @temporary_directory)
      splitter.layers_in(source_file).length.should eq 10
    end
  end

  def path_to(filepath)
    File.expand_path(
      File.join(File.dirname(__FILE__), "../fixtures/#{filepath}")
    )
  end
end

