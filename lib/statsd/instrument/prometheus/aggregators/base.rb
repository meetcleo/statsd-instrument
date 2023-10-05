# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      module Aggregators
        class Base
          def initialize(datagrams, **options)
            @datagrams = datagrams
            @options = options
          end

          def aggregate
            StatsD.logger.warn do
              "[#{self.class.name}] Events were dropped because no aggregator defined for type: #{datagrams.last&.type}"
            end

            nil
          end

          private

          attr_reader :datagrams, :options
        end
      end
    end
  end
end
