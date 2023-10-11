# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      class FlushStats
        def initialize(datagrams, default_tags, pre_aggregation_number_of_metrics, number_of_requests_attepted,
          number_of_requests_succeeded)
          @datagrams = datagrams
          @default_tags = default_tags
          @pre_aggregation_number_of_metrics = pre_aggregation_number_of_metrics
          @number_of_requests_attepted = number_of_requests_attepted
          @number_of_requests_succeeded = number_of_requests_succeeded
        end

        def run
          datagrams + flush_stats
        end

        private

        attr_reader :datagrams,
          :default_tags,
          :pre_aggregation_number_of_metrics,
          :number_of_requests_attepted,
          :number_of_requests_succeeded

        def flush_stats
          [
            DogStatsDDatagram.new(
              DogStatsDDatagramBuilder.new(default_tags: default_tags).g(
                "metrics_since_last_flush",
                datagrams.count,
                nil,
                nil,
              ),
            ),
            DogStatsDDatagram.new(
              DogStatsDDatagramBuilder.new(default_tags: default_tags).g(
                "pre_aggregation_number_of_metrics_since_last_flush",
                pre_aggregation_number_of_metrics,
                nil,
                nil,
              ),
            ),
            DogStatsDDatagram.new(
              DogStatsDDatagramBuilder.new(default_tags: default_tags).c(
                "number_of_requests_attepted.total",
                number_of_requests_attepted,
                nil,
                nil,
              ),
            ),
            DogStatsDDatagram.new(
              DogStatsDDatagramBuilder.new(default_tags: default_tags).c(
                "number_of_requests_succeeded_upto_previous_flush.total",
                number_of_requests_succeeded,
                nil,
                nil,
              ),
            ),
          ]
        end
      end
    end
  end
end
