# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      class FlushStats
        def initialize(datagrams, default_tags)
          @datagrams = datagrams
          @default_tags = default_tags
        end

        def run
          datagrams + [flush_stats]
        end

        private

        attr_reader :datagrams, :default_tags

        def flush_stats
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
