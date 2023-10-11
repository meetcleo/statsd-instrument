# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      class FlushStats
        def initialize(datagrams, default_tags, pre_aggregation_number_of_metrics, number_of_requests_attepted,
          number_of_requests_succeeded, number_of_metrics_dropped_due_to_buffer_full, last_flush_initiated_time)
          @datagrams = datagrams
          @default_tags = default_tags
          @pre_aggregation_number_of_metrics = pre_aggregation_number_of_metrics
          @number_of_requests_attepted = number_of_requests_attepted
          @number_of_requests_succeeded = number_of_requests_succeeded
          @number_of_metrics_dropped_due_to_buffer_full = number_of_metrics_dropped_due_to_buffer_full
          @last_flush_initiated_time = last_flush_initiated_time
        end

        def run
          datagrams + flush_stats
        end

        private

        attr_reader :datagrams,
          :default_tags,
          :pre_aggregation_number_of_metrics,
          :number_of_requests_attepted,
          :number_of_requests_succeeded,
          :number_of_metrics_dropped_due_to_buffer_full,
          :last_flush_initiated_time

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
            DogStatsDDatagram.new(
              DogStatsDDatagramBuilder.new(default_tags: default_tags).c(
                "number_of_metrics_dropped_due_to_buffer_full.total",
                number_of_metrics_dropped_due_to_buffer_full,
                nil,
                nil,
              ),
            ),
            DogStatsDDatagram.new(
              DogStatsDDatagramBuilder.new(default_tags: default_tags).g(
                "time_since_last_flush_initiated",
                (Time.now - last_flush_initiated_time) * 1000,
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
