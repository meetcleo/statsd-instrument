# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      module Aggregators
        class Sum < Base
          def aggregate
            last_datagram = datagrams.pop
            sum = datagrams.inject(last_datagram.value) do |accumulator, datagram|
              accumulator + datagram.value
            end

            DogStatsDDatagram.new(
              DogStatsDDatagramBuilder.new.c(
                "#{last_datagram.name}.total",
                sum,
                last_datagram.sample_rate,
                last_datagram.tags,
              ),
            )
          end
        end
      end
    end
  end
end
