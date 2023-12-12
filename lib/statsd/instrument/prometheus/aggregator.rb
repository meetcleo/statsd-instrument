# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      class Aggregator
        def initialize(datagrams, percentiles = nil, histograms = nil)
          @datagrams = datagrams
          @percentiles = percentiles
          @histograms = histograms
          @pre_aggregation_number_of_metrics = 0
          @number_of_metrics_failed_to_parse = 0
        end

        def run
          aggregated_datagrams.compact
        end

        attr_reader :pre_aggregation_number_of_metrics, :number_of_metrics_failed_to_parse

        private

        attr_reader :datagrams, :percentiles, :histograms

        def datagrams_by_type_then_key
          datagrams.split.map do |datagram|
            @pre_aggregation_number_of_metrics += 1
            try_parse_metric(datagram)
          end.compact.group_by(&:type).to_h do |type, parsed_datagrams|
            [type, parsed_datagrams.group_by(&:key).to_h]
          end
        end

        def aggregated_datagrams
          datagrams_by_type_then_key.flat_map do |type, datagrams_by_key|
            datagrams_by_key.flat_map do |_, datagrams_for_key|
              aggregation_class_for_type(type).new(datagrams_for_key, percentiles: percentiles, histograms: histograms).aggregate
            end
          end
        end

        def try_parse_metric(datagram)
          parsed_datagram = DogStatsDDatagram.new(datagram)
          parsed_datagram.key # Need to access something on the datagram to trigger the parse
          parsed_datagram
        rescue ArgumentError
          @number_of_metrics_failed_to_parse += 1
          nil
        end

        def aggregation_class_for_type(type)
          case type
          when :c
            Aggregators::Sum
          when :ms
            Aggregators::Timing
          when :g
            Aggregators::LastValue
          else
            Aggregators::Unsupported
          end
        end
      end
    end
  end
end
