# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      class Serializer
        def initialize(datagrams)
          @datagrams = datagrams
          @current_time_ms = (Time.now.to_f * 1000).to_i
        end

        def run
          ::Prometheus::WriteRequest.encode(::Prometheus::WriteRequest.new(timeseries: stats, metadata: []))
        end

        private

        attr_reader :datagrams, :current_time_ms

        def stats
          @stats ||= datagrams.map do |datagram|
            ::Prometheus::TimeSeries.new(
              labels: [::Prometheus::Label.new(name: '__name__', value: datagram.name)], # TODO: set all labels
              samples: [::Prometheus::Sample.new(timestamp: current_time_ms, value: datagram.value)], # TODO: calculate for different types
            )
          end
        end
      end
    end
  end
end
