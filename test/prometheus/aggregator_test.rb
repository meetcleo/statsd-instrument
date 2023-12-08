# frozen_string_literal: true

require "test_helper"

module Prometheus
  class AggregatorTest < Minitest::Test
    def test_run_with_no_aggregations
      aggregator = described_class.new("foo:1|c\nfo_o:10|c|@0.1\nfoo:1|g\nfo_o:10|s|@0.01\nfoo:1|h\nfoo:1|d|#foo,bar")
      assert_equal(3, aggregator.run.length)
    end

    def test_run_with_sums
      aggregator = described_class.new("foo:10|c\nfoo:1|c\nfoo:1|c\nfoo:2|c")
      assert_equal(1, aggregator.run.length)
      assert_equal(14, aggregator.run.last.value)
    end

    def test_run_with_failed_parse
      aggregator = described_class.new("bar::1|c\nfoo:10|c\nfoo:1|c\nfoo:1|c\nfoo:2|c")
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

    def test_run_with_timer_and_percentiles
      values = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95]
      aggregator = described_class.new(values.map { |value| "foo:#{value}|ms" }.join("\n"), [90, 95])
      assert_equal(6, aggregator.run.length)
      actual = aggregator.run
      expected = [
        "foo.sum_90:765.0|ms",
        "foo.sum_95:855.0|ms",
        "foo.sum:950.0|ms",
        "foo.count_90:18|c",
        "foo.count_95:19|c",
        "foo.count:20|c",
      ]
      assert_equal(expected, actual.map(&:source))
    end

    def test_run_with_timer_and_percentiles_one_value
      values = [5]
      aggregator = described_class.new(values.map { |value| "foo:#{value}|ms" }.join("\n"), [90, 95])
      assert_equal(6, aggregator.run.length)
      actual = aggregator.run
      expected = [
        "foo.sum_90:5.0|ms",
        "foo.sum_95:5.0|ms",
        "foo.sum:5.0|ms",
        "foo.count_90:1|c",
        "foo.count_95:1|c",
        "foo.count:1|c",
      ]
      assert_equal(expected, actual.map(&:source))
    end

    def test_run_with_timer
      values = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95]
      aggregator = described_class.new(values.map { |value| "foo:#{value}|ms" }.join("\n"), [])
      assert_equal(2, aggregator.run.length)
      actual = aggregator.run
      expected = [
        "foo.sum:950.0|ms",
        "foo.count:20|c",
      ]
      assert_equal(expected, actual.map(&:source))
    end

    def test_run_with_timer_and_histograms
      values = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95]
      aggregator = described_class.new(values.map { |value| "foo:#{value}|ms" }.join("\n"), [], [10, 30, 50, 90])
      assert_equal(7, aggregator.run.length)
      actual = aggregator.run
      expected = [
        "foo.sum:950.0|ms",
        "foo.count:20|c",
        "foo.bucket:3|c|#le:10",
        "foo.bucket:7|c|#le:30",
        "foo.bucket:11|c|#le:50",
        "foo.bucket:19|c|#le:90",
        "foo.bucket:20|c|#le:+Inf",
      ]
      assert_equal(expected, actual.map(&:source))
    end

    def test_run_with_timer_and_histograms_existing_tag
      values = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95]
      aggregator = described_class.new(values.map { |value| "foo:#{value}|ms|#host:abc" }.join("\n"), [], [10, 30, 50, 90])
      assert_equal(7, aggregator.run.length)
      actual = aggregator.run
      expected = [
        "foo.sum:950.0|ms|#host:abc",
        "foo.count:20|c|#host:abc",
        "foo.bucket:3|c|#host:abc,le:10",
        "foo.bucket:7|c|#host:abc,le:30",
        "foo.bucket:11|c|#host:abc,le:50",
        "foo.bucket:19|c|#host:abc,le:90",
        "foo.bucket:20|c|#host:abc,le:+Inf",
      ]
      assert_equal(expected, actual.map(&:source))
    end

    private

    def described_class
      StatsD::Instrument::Prometheus::Aggregator
    end
  end
end
