# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      module Aggregators
        class Timing < Base
          def aggregate
            # TODO
            datagrams.last
          end

          private

          attr_reader :datagrams
        end
      end
    end
  end
end