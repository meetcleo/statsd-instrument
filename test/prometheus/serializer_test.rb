# frozen_string_literal: true

require "test_helper"

module Prometheus
  class SerializerTest < Minitest::Test
    def test_run_with_no_aggregations
      serializer = described_class.new([::StatsD::Instrument::DogStatsDDatagram.new("foo:1|d|#lab1:1,lab2:2,skipped")], nil, nil)
      output = serializer.run
      decoded_output = ::Prometheus::WriteRequest.decode(output)
      timeseries = decoded_output.timeseries
      assert_equal(1, timeseries.length)

      metric = timeseries[0]
      assert_equal(["__name__", "host", "lab1", "lab2", "pid"].sort, metric.labels.map(&:name).sort)
      assert_equal(
        [
          ::Prometheus::Label.new(name: "__name__", value: "foo"),
          ::Prometheus::Label.new(name: "lab1", value: "1"),
          ::Prometheus::Label.new(name: "lab2", value: "2"),
        ],
        metric.labels.select { |label| ["__name__", "lab1", "lab2"].include?(label.name) },
      )
      assert_equal(1, metric.samples[0]&.value)
    end

    private

    def described_class
      StatsD::Instrument::Prometheus::Serializer
    end
  end
end