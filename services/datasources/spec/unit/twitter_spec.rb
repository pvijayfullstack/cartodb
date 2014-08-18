# encoding: utf-8

require_relative '../../lib/datasources'
require_relative '../doubles/user'

include CartoDB::Datasources

describe Search::Twitter do

  def get_config
    {
      'auth_required' => false,
      'username'      => '',
      'password'      => '',
      'search_url'    => 'http://fakeurl.cartodb'
    }
  end #get_config

  before(:each) do
    Typhoeus::Expectation.clear
  end

  describe '#filters' do
    it 'tests category filters' do
      user_mock = Doubles::User.new

      twitter_datasource = Search::Twitter.get_new(get_config, user_mock)

      input_terms = terms_fixture

      expected_output_terms = [
          {
            Search::Twitter::CATEGORY_NAME_KEY  => 'Category 1',
            Search::Twitter::CATEGORY_TERMS_KEY => 'uno has:geo OR @dos has:geo OR #tres has:geo'
          },
          {
            Search::Twitter::CATEGORY_NAME_KEY  => 'Category 2',
            Search::Twitter::CATEGORY_TERMS_KEY => 'aaa has:geo OR bbb has:geo'
          }
      ]

      output = twitter_datasource.send :build_queries_from_fields, input_terms

      output.should eq expected_output_terms
    end

    it 'tests search term cut if too many' do
      user_mock = Doubles::User.new

      twitter_datasource = Search::Twitter.get_new(get_config, user_mock)

      input_terms = {
          categories: [
              {
                  category: 'Category 1',
                  terms:    Array(1..35)
              }
          ]
      }

      expected_output_terms = [
          {
              Search::Twitter::CATEGORY_NAME_KEY  => 'Category 1',
              Search::Twitter::CATEGORY_TERMS_KEY => '1 has:geo OR 2 has:geo OR 3 has:geo OR 4 has:geo OR 5 has:geo OR 6 has:geo OR 7 has:geo OR 8 has:geo OR 9 has:geo OR 10 has:geo OR 11 has:geo OR 12 has:geo OR 13 has:geo OR 14 has:geo OR 15 has:geo OR 16 has:geo OR 17 has:geo OR 18 has:geo OR 19 has:geo OR 20 has:geo OR 21 has:geo OR 22 has:geo OR 23 has:geo OR 24 has:geo OR 25 has:geo OR 26 has:geo OR 27 has:geo OR 28 has:geo OR 29 has:geo OR 30 has:geo'
          },
      ]

      output = twitter_datasource.send :build_queries_from_fields, input_terms
      output.should eq expected_output_terms
    end

    it 'tests search term cut if too big (even if amount is ok)' do
      user_mock = Doubles::User.new

      twitter_datasource = Search::Twitter.get_new(get_config, user_mock)

      input_terms = {
          categories: [
              {
                  category: 'Category 1',
                  terms:    ['wadus1', 'wadus2', 'wadus3' * 500]
              }
          ]
      }

      expected_output_terms = [
          {
              Search::Twitter::CATEGORY_NAME_KEY  => 'Category 1',
              Search::Twitter::CATEGORY_TERMS_KEY => 'wadus1 has:geo OR wadus2 has:geo'
          },
      ]

      output = twitter_datasource.send :build_queries_from_fields, input_terms
      output.should eq expected_output_terms
    end


    it 'tests date filters' do
      user_mock = Doubles::User.new

      twitter_datasource = Search::Twitter.get_new(get_config, user_mock)

      input_dates = dates_fixture

      output = twitter_datasource.send :build_date_from_fields, input_dates, 'from'
      output.should eq '201403031349'

      output = twitter_datasource.send :build_date_from_fields, input_dates, 'to'
      output.should eq '201403041159'

      expect {
        twitter_datasource.send :build_date_from_fields, input_dates, 'wadus'
      }.to raise_error ParameterError


      current_time = Time.now
      output = twitter_datasource.send :build_date_from_fields, {
        dates: {
          toDate:   current_time.strftime("%Y-%m-%d"),
          toHour:   current_time.hour + 1,  # Set into the future
          toMin:    current_time.min
        }
      }, 'to'
      output.should eq nil

    end

    it 'tests twitter search integration (without conversion to CSV)' do
      # This test bridges lots of internal calls to simulate only up until twitter search call and results
      user_mock = Doubles::User.new

      twitter_datasource = Search::Twitter.get_new(get_config, user_mock)

      input_terms = terms_fixture
      input_dates = dates_fixture

      Typhoeus.stub(/fakeurl\.cartodb/) do |request|
        accept = (request.options[:headers]||{})['Accept'] || 'application/json'
        format = accept.split(',').first

        if request.options[:params][:next].nil?
          body = data_from_file('sample_tweets.json')
        else
          body = data_from_file('sample_tweets_2.json')
        end

        Typhoeus::Response.new(
            code: 200,
            headers: { 'Content-Type' => format },
            body: body
        )
      end

      twitter_api = twitter_datasource.send :search_api

      fields = {
        categories: input_terms[:categories],
        dates:      input_dates[:dates]
      }
      filters = {
          Search::Twitter::FILTER_CATEGORIES =>    (twitter_datasource.send :build_queries_from_fields, fields),
          Search::Twitter::FILTER_FROMDATE =>      (twitter_datasource.send :build_date_from_fields, fields, 'from'),
          Search::Twitter::FILTER_TODATE =>        (twitter_datasource.send :build_date_from_fields, fields, 'to'),
          Search::Twitter::FILTER_MAXRESULTS =>    500,
          Search::Twitter::FILTER_TOTAL_RESULTS => Search::Twitter::NO_TOTAL_RESULTS
      }

      output = twitter_datasource.send :search_by_category, \
        twitter_api, filters, input_terms[:categories].first, user_mock

      # 2 pages of 10 results per category search
      output.count.should eq 20
    end

    it 'tests basic full search flow' do
      user_mock = Doubles::User.new

      twitter_datasource = Search::Twitter.get_new(get_config, user_mock)

      input_terms = terms_fixture
      input_dates = dates_fixture

      Typhoeus.stub(/fakeurl\.cartodb/) do |request|
        accept = (request.options[:headers]||{})['Accept'] || 'application/json'
        format = accept.split(',').first

        if request.options[:params][:next].nil?
          body = data_from_file('sample_tweets.json')
        else
          body = data_from_file('sample_tweets_2.json')
        end

        Typhoeus::Response.new(
          code: 200,
          headers: { 'Content-Type' => format },
          body: body
        )
      end

      output = twitter_datasource.get_resource(::JSON.dump(
        {
          categories: input_terms[:categories],
          dates:      input_dates[:dates]
        }
      ))

      output.should eq data_from_file('sample_tweets_expected.csv')

    end

  end

  protected

  def terms_fixture
    {
      categories: [
        {
          category: 'Category 1',
          terms:    ['uno', '@dos', '#tres']
        },
        {
          category: 'Category 2',
          terms:    ['aaa', 'bbb']
        }
      ]
    }
  end

  def dates_fixture
    {
      dates: {
        fromDate: '2014-03-03',
        fromHour: '13',
        fromMin:  '49',
        toDate:   '2014-03-04',
        toHour:   '11',
        toMin:    '59'
      }
    }
  end

  def data_from_file(filename)
    File.read(File.join(File.dirname(__FILE__), "../fixtures/#{filename}"))
  end

end

