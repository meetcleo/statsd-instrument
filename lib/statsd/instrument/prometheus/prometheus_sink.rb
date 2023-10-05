# frozen_string_literal: true
require "snappy"

module StatsD
  module Instrument
    module Prometheus
      class PrometheusSink < ::StatsD::Instrument::UDPSink
        THREAD_NAME = "StatsD::PrometheusSink"

        class << self
          def for_addr(addr)
            new(addr)
          end

          def close_socket(socket)
            socket&.finish
          end

          def thread_name
            THREAD_NAME
          end
        end

        attr_reader :uri, :auth_key, :percentiles

        def initialize(addr, auth_key, percentiles) # rubocop:disable Lint/MissingSuper
          ObjectSpace.define_finalizer(self, FINALIZER)
          @uri = URI(addr)
          @auth_key = auth_key
          @percentiles = percentiles
        end

        def <<(datagram)
          invalidate_socket_and_retry_if_error do
            response = make_request(datagram)
            StatsD.logger.warn do
              "[#{self.class.name}] Events were dropped because of response code from Prometheus: #{response.code}"
            end unless response.code == "201"
          end
          self
        end

        private

        def request_body(datagram)
          aggregated = StatsD::Instrument::Prometheus::Aggregator.new(datagram, percentiles).run
          serialized = StatsD::Instrument::Prometheus::Serializer.new(aggregated).run
          Snappy.deflate(serialized)
        end

        def make_request(datagram)
          request = Net::HTTP::Post.new(uri.request_uri)
          request["Authorization"] = "Bearer #{auth_key}"
          request.body = request_body(datagram)
          socket.request(request)
        end

        def build_socket
          socket = Net::HTTP.new(uri.host, uri.port)
          socket.use_ssl = true
          socket.set_debug_output($stdout) # TODO: remove
          socket.start
          socket
        end
      end
    end
  end
end
