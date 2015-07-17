# encoding: utf-8

require_relative '../../spec_helper'

describe ActiveRecord::ConnectionAdapters::PostgreSQLAdapter do
  describe '#survive_failure' do

    it 'Should survive a PostgreSQL disconnection' do
      # We don't care about whether a visualization exists, we just want some activity
      viz1 = Carto::Visualization.first
      #break the AR connection on purpose
      expect {
        ActiveRecord::Base.connection.exec_query("SELECT pg_terminate_backend(pg_backend_pid())")
      }.to raise_exception(ActiveRecord::StatementInvalid)
      viz2 = Carto::Visualization.first
    end
  end

end
