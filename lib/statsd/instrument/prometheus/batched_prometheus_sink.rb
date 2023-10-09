# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      class BatchedPrometheusSink < ::StatsD::Instrument::BatchedUDPSink
        # https://coralogix.com/docs/coralogix-endpoints/
        DEFAULT_MAX_PACKET_SIZE = 1_200_000 # 1.2 MB

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
          percentiles:,
          application_name:,
          subsystem:,
          default_tags:,
          open_timeout:,
          read_timeout:,
          write_timeout:
        )
          dispatcher = PeriodicDispatcher.new(
            nil,
            nil,
            buffer_capacity,
            thread_priority,
            max_packet_size,
            PrometheusSink.new(
              addr,
              auth_key,
              percentiles,
              application_name,
              subsystem,
              default_tags,
              open_timeout,
              read_timeout,
              write_timeout,
            ),
          )
          super(
            host,
            port,
            thread_priority: thread_priority,
            buffer_capacity: buffer_capacity,
            max_packet_size: max_packet_size,
            dispatcher: dispatcher
          )
        end
      end
    end
  end
end
