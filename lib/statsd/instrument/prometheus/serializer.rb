# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      class Serializer
        # Colon separated, but allows double-colon values, e.g. name:value, name.1:value.1, name:Module1::Module2::Class
        LABEL_EXTRACTOR = /^(?<name>[^\:]+)\:(?<value>.+)$/

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
          datagrams.map do |datagram|
            ::Prometheus::TimeSeries.new(
              labels: labels(datagram),
              samples: [::Prometheus::Sample.new(timestamp: current_time_ms, value: datagram.value)], # TODO: calculate for different types
            )
          end
        end

        def labels(datagram)
          labels = [::Prometheus::Label.new(name: "__name__", value: datagram.name)]
          return labels unless datagram.tags

          labels + datagram.tags.map do |tag|
            if (matches = LABEL_EXTRACTOR.match(tag))
              ::Prometheus::Label.new(name: matches["name"], value: matches["value"])
            end
          end.compact
        end
      end
    end
  end
end
