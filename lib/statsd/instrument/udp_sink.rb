# frozen_string_literal: true

module StatsD
  module Instrument
    # @note This class is part of the new Client implementation that is intended
    #   to become the new default in the next major release of this library.
    class UDPSink
      THREAD_NAME = "StatsD::UDPSink"

      class << self
        def for_addr(addr)
          host, port_as_string = addr.split(":", 2)
          new(host, Integer(port_as_string))
        end

        def close_socket(socket)
          socket&.close
        end

        def thread_name
          THREAD_NAME
        end
      end

      attr_reader :host, :port

      FINALIZER = ->(object_id) do
        Thread.list.each do |thread|
          if (store = thread[thread_name])
            close_socket(store.delete(object_id))
          end
        end
      end

      def initialize(host, port)
        ObjectSpace.define_finalizer(self, FINALIZER)
        @host = host
        @port = port
      end

      def sample?(sample_rate)
        sample_rate == 1.0 || rand < sample_rate
      end

      def <<(datagram)
        invalidate_socket_and_retry_if_error do
          socket.send(datagram, 0)
        end
        self
      end

      private

      def invalidate_socket_and_retry_if_error
        retried = false
        begin
          yield
        rescue SocketError, IOError, SystemCallError, Net::OpenTimeout, Errno::ECONNREFUSED, HTTPX::HTTPError => error
          StatsD.logger.debug do
            "[StatsD::Instrument::UDPSink] Resetting connection because of #{error.class}: #{error.message}"
          end
          invalidate_socket
          if retried
            StatsD.logger.warn do
              "[#{self.class.name}] Events were dropped because of #{error.class}: #{error.message}"
            end
          else
            retried = true
            retry if retries_allowed?
          end
        end
      end

      def invalidate_socket
        socket = thread_store.delete(object_id)
        self.class.close_socket(socket)
      end

      def socket
        thread_store[object_id] ||= build_socket
      end

      def build_socket
        socket = UDPSocket.new
        socket.connect(@host, @port)
        socket
      end

      def thread_store
        Thread.current[self.class.thread_name] ||= {}
      end

      def retries_allowed?
        true
      end
    end
  end
end
