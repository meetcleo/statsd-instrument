# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      class FlushStats
        def initialize(datagrams)
          @datagrams = datagrams
        end

        def run
          datagrams + [flush_stats]
        end

        private

        attr_reader :datagrams

        def flush_stats
          env = StatsD::Instrument::Environment.current
          default_tags = env.statsd_default_tags

          DogStatsDDatagram.new(
            DogStatsDDatagramBuilder.new(default_tags: default_tags).g(
              "metrics_since_last_flush",
              datagrams.count,
              nil,
              nil,
            ),
          )
        end
      end
    end
  end
end
