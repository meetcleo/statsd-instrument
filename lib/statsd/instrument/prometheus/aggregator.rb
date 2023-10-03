# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      class Aggregator
        def initialize(datagrams)
          @datagrams = datagrams
        end

        def run
          # TODO: actually aggregate
          datagrams_by_type_then_name.flat_map { |type, datagrams_by_name| datagrams_by_name.values }.flatten
        end

        private

        attr_reader :datagrams

        def datagrams_by_type_then_name
          @datagrams_by_type_then_name ||= datagrams.split.map do |datagram|
            DogStatsDDatagram.new(datagram)
          end.group_by(&:type).to_h do |type, parsed_datagrams|
            [type, parsed_datagrams.group_by(&:name).to_h]
          end
        end
      end
    end
  end
end
