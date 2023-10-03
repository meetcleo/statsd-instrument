# frozen_string_literal: true

require "test_helper"

module Prometheus
  class SerializerTest < Minitest::Test
    def test_run_with_no_aggregations
      serializer = described_class.new([::StatsD::Instrument::DogStatsDDatagram.new("foo:1|d|#foo,bar")])
      output = serializer.run
      decoded_output = ::Prometheus::WriteRequest.decode(output)
      timeseries = decoded_output.timeseries
      assert_equal(1, timeseries.length)

      metric = timeseries[0]
      assert_equal([::Prometheus::Label.new(name: "__name__", value: "foo")], metric.labels)
      assert_equal(1, metric.samples[0]&.value)
    end

    private

    def described_class
      StatsD::Instrument::Prometheus::Serializer
    end
  end
end