# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      class Aggregator
        def initialize(datagrams, percentiles = nil)
          @datagrams = datagrams
          @percentiles = percentiles
          @pre_aggregation_number_of_metrics = 0
        end

        def run
          aggregated_datagrams.compact
        end

        attr_reader :pre_aggregation_number_of_metrics

        private

        attr_reader :datagrams, :percentiles

        def datagrams_by_type_then_key
          datagrams.split.map do |datagram|
            @pre_aggregation_number_of_metrics += 1
            DogStatsDDatagram.new(datagram)
          end.group_by(&:type).to_h do |type, parsed_datagrams|
            [type, parsed_datagrams.group_by(&:key).to_h]
          end
        end

        def aggregated_datagrams
          datagrams_by_type_then_key.flat_map do |type, datagrams_by_key|
            datagrams_by_key.flat_map do |_, datagrams_for_key|
              aggregation_class_for_type(type).new(datagrams_for_key, percentiles: percentiles).aggregate
            end
          end
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
