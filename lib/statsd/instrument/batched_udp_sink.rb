# frozen_string_literal: true

module StatsD
  module Instrument
    # @note This class is part of the new Client implementation that is intended
    #   to become the new default in the next major release of this library.
    class BatchedUDPSink
      DEFAULT_THREAD_PRIORITY = 100
      DEFAULT_BUFFER_CAPACITY = 5_000
      # https://docs.datadoghq.com/developers/dogstatsd/high_throughput/?code-lang=ruby#ensure-proper-packet-sizes
      DEFAULT_MAX_PACKET_SIZE = 1472

      attr_reader :host, :port

      class << self
        def for_addr(addr, **kwargs)
          host, port_as_string = addr.split(":", 2)
          new(host, Integer(port_as_string), **kwargs)
        end

        def finalize(dispatcher)
          proc { dispatcher.shutdown }
        end
      end

      def initialize(
        host,
        port,
        thread_priority: DEFAULT_THREAD_PRIORITY,
        buffer_capacity: DEFAULT_BUFFER_CAPACITY,
        max_packet_size: DEFAULT_MAX_PACKET_SIZE,
        dispatcher: nil
      )
        @host = host
        @port = port
        @dispatcher = dispatcher || Dispatcher.new(
          host,
          port,
          buffer_capacity,
          thread_priority,
          max_packet_size,
        )
        ObjectSpace.define_finalizer(self, self.class.finalize(@dispatcher))
      end

      def sample?(sample_rate)
        sample_rate == 1.0 || rand < sample_rate
      end

      def <<(datagram)
        @dispatcher << datagram
        self
      end

      def shutdown(*args)
        @dispatcher.shutdown(*args)
      end
    end
  end
end
