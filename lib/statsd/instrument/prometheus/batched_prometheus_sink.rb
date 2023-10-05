# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      class BatchedPrometheusSink < ::StatsD::Instrument::BatchedUDPSink
        class << self
          def for_addr(addr, **kwargs)
            new(addr, **kwargs)
          end

          def finalize(dispatcher)
            proc { dispatcher.shutdown }
          end
        end

        def initialize(
          addr,
          thread_priority: DEFAULT_THREAD_PRIORITY,
          buffer_capacity: DEFAULT_BUFFER_CAPACITY,
          max_packet_size: DEFAULT_MAX_PACKET_SIZE,
          auth_key:,
          percentiles:
        )
          dispatcher = Dispatcher.new(
            nil,
            nil,
            buffer_capacity,
            thread_priority,
            max_packet_size,
            PrometheusSink.new(addr, auth_key, percentiles),
          )
          super(
            host,
            port,
            thread_priority: DEFAULT_THREAD_PRIORITY,
            buffer_capacity: DEFAULT_BUFFER_CAPACITY,
            max_packet_size: DEFAULT_MAX_PACKET_SIZE,
            dispatcher: dispatcher
          )
        end
      end
    end
  end
end
