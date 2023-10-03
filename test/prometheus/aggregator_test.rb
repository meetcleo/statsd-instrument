# frozen_string_literal: true

require "test_helper"

module Prometheus
  class AggregatorTest < Minitest::Test
    def test_run_with_no_aggregations
      aggregator = described_class.new("foo:1|c\nfo_o:10|ms|@0.1\nfoo:1|g\nfo_o:10|s|@0.01\nfoo:1|h\nfoo:1|d|#foo,bar")
      assert_equal(6, aggregator.run.length)
    end

    private

    def described_class
      StatsD::Instrument::Prometheus::Aggregator
    end
  end
end