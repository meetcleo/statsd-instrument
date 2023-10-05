# frozen_string_literal: true

require "test_helper"

module Prometheus
  class AggregatorTest < Minitest::Test
    def test_run_with_no_aggregations
      aggregator = described_class.new("foo:1|c\nfo_o:10|ms|@0.1\nfoo:1|g\nfo_o:10|s|@0.01\nfoo:1|h\nfoo:1|d|#foo,bar")
      assert_equal(3, aggregator.run.length)
    end

    def test_run_with_sums
      aggregator = described_class.new("foo:10|c\nfoo:1|c\nfoo:1|c\nfoo:2|c")
      assert_equal(1, aggregator.run.length)
      assert_equal(14, aggregator.run.last.value)
    end

    def test_run_with_last_value
      aggregator = described_class.new("foo:10|g\nfoo:1|g\nfoo:1|g\nfoo:2|g")
      assert_equal(1, aggregator.run.length)
      assert_equal(2, aggregator.run.last.value)
    end

    def test_run_with_unsupported
      aggregator = described_class.new("foo:10|s\nfoo:1|s\nfoo:1|s\nfoo:2|s")
      assert_equal(0, aggregator.run.length)
    end

    def test_run_aggregates_by_type_and_key
      source = "foo:1|c|#foo,bar\nfoo:10|c|#foo,baz\nfoo:1|g|#foo,bar\n"
      aggregator = described_class.new(source)
      assert_equal(3, aggregator.run.length)
      expected = "foo.total:1|c|#foo,bar\nfoo.total:10|c|#foo,baz\nfoo:1|g|#foo,bar\n"
      assert_equal(expected.split, aggregator.run.map(&:source))
    end

    private

    def described_class
      StatsD::Instrument::Prometheus::Aggregator
    end
  end
end