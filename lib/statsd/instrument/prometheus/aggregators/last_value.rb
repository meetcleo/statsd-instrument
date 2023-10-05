# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      module Aggregators
        class LastValue < Base
          def aggregate
            datagrams.last
          end
        end
      end
    end
  end
end