# frozen_string_literal: true
require 'snappy'

module StatsD
  module Instrument
    module Prometheus
      class PrometheusSink
        THREAD_NAME = "StatsD::PrometheusSink"

        class << self
          def for_addr(addr)
            new(addr)
          end
        end

        attr_reader :uri, :auth_key

        FINALIZER = ->(object_id) do
          Thread.list.each do |thread|
            if (store = thread[THREAD_NAME])
              store.delete(object_id)&.finish
            end
          end
        end

        def initialize(addr, auth_key)
          ObjectSpace.define_finalizer(self, FINALIZER)
          @uri = URI(addr)
          @auth_key = auth_key
        end

        def sample?(sample_rate)
          sample_rate == 1.0 || rand < sample_rate
        end

        def <<(datagram)
          retried = false
          begin
            response = make_request(datagram)
            StatsD.logger.warn do
              "[#{self.class.name}] Events were dropped because of response code from Prometheus: #{response.code}"
            end unless response.code == '201'
          rescue SocketError, IOError, SystemCallError, EOFError, Net::ReadTimeout => error
            StatsD.logger.debug do
              "[#{self.class.name}] Resetting connection because of #{error.class}: #{error.message}"
            end
            invalidate_socket
            if retried
              StatsD.logger.warn do
                "[#{self.class.name}] Events were dropped because of #{error.class}: #{error.message}"
              end
            else
              retried = true
              retry
            end
          end
          self
        end

        private

        def request_body(datagram)
          aggregated = StatsD::Instrument::Prometheus::Aggregator.new(datagram).run
          serialized = StatsD::Instrument::Prometheus::Serializer.new(aggregated).run
          Snappy.deflate(serialized)
        end

        def make_request(datagram)
          request = Net::HTTP::Post.new(uri.request_uri)
          request['Authorization'] = "Bearer #{auth_key}"
          request.body = request_body(datagram)
          socket.request(request)
        end

        def invalidate_socket
          socket = thread_store.delete(object_id)
          socket&.finish
        end

        def socket
          thread_store[object_id] ||= begin
            socket = Net::HTTP.new(uri.host, uri.port)
            socket.use_ssl = true
            socket.set_debug_output($stdout) # TODO: remove
            socket.start
            socket
          end
        end

        def thread_store
          Thread.current[THREAD_NAME] ||= {}
        end
      end
    end
  end
end
