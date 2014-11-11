# encoding: utf-8

require_relative '../../lib/importer/content_guesser'

RSpec.configure do |config|
  config.mock_with :mocha
end

describe CartoDB::Importer2::ContentGuesser do

  describe '#enabled?' do
    it 'returns a true value if set so in options' do
      guesser = CartoDB::Importer2::ContentGuesser.new nil, nil, nil, {guessing: {enabled: true}}
      guesser.enabled?.should eq true
    end

    it 'returns a false value if set so in options' do
      guesser = CartoDB::Importer2::ContentGuesser.new nil, nil, nil, {guessing: {enabled: false}}
      guesser.enabled?.should eq false
    end

    it 'returns a false-like value if not set in options' do
      guesser = CartoDB::Importer2::ContentGuesser.new nil, nil, nil, {}
      guesser.enabled?.should eq false
    end

  end

  describe '#country_column' do
    it 'returns nil if guessing is not enabled' do
      guesser = CartoDB::Importer2::ContentGuesser.new nil, nil, nil, {guessing: {enabled: false}}
      guesser.country_column.should eq nil
    end

    it 'returns the first column name which contents are countries, if present' do
      guesser = CartoDB::Importer2::ContentGuesser.new nil, nil, nil, {guessing: {enabled: true}}
      columns = [
        {column_name: 'any_column' },
        {column_name: 'country_column'},
        {column_name: 'any_other_column'}
      ]
      guesser.stubs(:columns).returns(columns)
      guesser.stubs(:is_country_column?).with({column_name: 'any_column'}).returns(false)
      guesser.stubs(:is_country_column?).with({column_name: 'country_column'}).returns(true)
      guesser.stubs(:is_country_column?).with({column_name: 'any_other_column'}).returns(false)

      guesser.country_column.should eq 'country_column'
    end

    it "returns nil if there's no column containing countries" do
      guesser = CartoDB::Importer2::ContentGuesser.new nil, nil, nil, {guessing: {enabled: true}}
      columns = [
        {column_name: 'any_column' },
        {column_name: 'any_other_column'}
      ]
      guesser.stubs(:columns).returns(columns)
      guesser.stubs(:is_country_column?).returns(false)

      guesser.country_column.should be_nil
    end
  end

  describe '#columns' do
    it 'queries the db to get a list of columns with their corresponding data types' do
      db = mock
      db.expects(:[]).returns(:any_iterable_list_of_columnts)
      table_name = 'any_table_name'
      schema = 'any_schema'
      guesser = CartoDB::Importer2::ContentGuesser.new db, table_name, schema, nil
      guesser.columns.should == :any_iterable_list_of_columnts
    end
  end

  describe '#is_country_column?' do
    it 'returns true if a sample proportion is above a given threshold' do
      guesser = CartoDB::Importer2::ContentGuesser.new nil, nil, nil, nil
      column = {column_name: 'candidate_column_name', data_type: 'text'}
      guesser.stubs(:sample).returns [
         {candidate_column_name: 'USA'},
         {candidate_column_name: 'Spain'},
         {candidate_column_name: 'not a country'}
      ]
      guesser.stubs(:countries).returns Set.new ['usa', 'spain', 'france', 'canada']
      guesser.stubs(:threshold).returns 0.5

      guesser.is_country_column?(column).should eq true
    end
  end

  describe '#is_country_column_type?' do
    it 'returns false if the column type is not compatible' do
      guesser = CartoDB::Importer2::ContentGuesser.new nil, nil, nil, nil
      column = {data_type: 'integer'}
      guesser.is_country_column_type?(column).should eq false
    end

    it 'returns true if the column type is of a compatible type' do
      guesser = CartoDB::Importer2::ContentGuesser.new nil, nil, nil, nil
      column = {data_type: 'text'}
      guesser.is_country_column_type?(column).should eq true
    end
  end

  describe '#countries' do
    it 'queries the sql api to get a Set of countries' do
      api_mock = mock
      api_mock
        .expects(:fetch)
        .with(CartoDB::Importer2::ContentGuesser::COUNTRIES_QUERY)
        .returns([
          {'synonyms' => ['usa', 'united states']},
          {'synonyms' => ['spain', 'es']},
          {'synonyms' => ['france', 'fr']}
        ])
      guesser = CartoDB::Importer2::ContentGuesser.new nil, nil, nil, nil
      guesser.geocoder_sql_api = api_mock
      guesser.countries.should eq Set.new ['usa', 'united states', 'spain', 'es', 'france', 'fr']
    end

    it 'caches the response so no need to call the sql api on successive calls' do
      api_mock = mock
      api_mock
        .expects(:fetch)
        .once
        .with(CartoDB::Importer2::ContentGuesser::COUNTRIES_QUERY)
        .returns([])
      guesser = CartoDB::Importer2::ContentGuesser.new nil, nil, nil, nil
      guesser.geocoder_sql_api = api_mock

      guesser.countries.should eq Set.new []
      guesser.countries.should eq Set.new []
    end
  end

end
