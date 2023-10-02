# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      class BatchedPrometheusSink < ::StatsD::Instrument::BatchedUDPSink
        def initialize(
          host,
          port,
          thread_priority: DEFAULT_THREAD_PRIORITY,
          buffer_capacity: DEFAULT_BUFFER_CAPACITY,
          max_packet_size: DEFAULT_MAX_PACKET_SIZE,
          auth_key:
        )
          dispatcher = Dispatcher.new(
            host,
            port,
            buffer_capacity,
            thread_priority,
            max_packet_size,
            PrometheusSink.new(host, port, auth_key),
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
