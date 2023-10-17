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

        attr_reader :uri,
          :auth_key,
          :percentiles,
          :application_name,
          :subsystem,
          :default_tags,
          :open_timeout,
          :read_timeout,
          :write_timeout,
          :number_of_requests_attempted,
          :number_of_requests_succeeded,
          :number_of_metrics_dropped_due_to_buffer_full,
          :last_flush_initiated_time,
          :basic_auth_user

        def initialize(addr, auth_key, percentiles, application_name, subsystem, default_tags, open_timeout, read_timeout, write_timeout, basic_auth_user) # rubocop:disable Lint/MissingSuper
          ObjectSpace.define_finalizer(self, FINALIZER)
          @uri = URI(addr)
          @auth_key = auth_key
          @percentiles = percentiles
          @application_name = application_name
          @subsystem = subsystem
          @default_tags = default_tags
          @open_timeout = open_timeout
          @read_timeout = read_timeout
          @write_timeout = write_timeout
          @number_of_requests_attempted = 0
          @number_of_requests_succeeded = 0
          @number_of_metrics_dropped_due_to_buffer_full = 0
          @last_flush_initiated_time = Time.now
          @basic_auth_user = basic_auth_user
        end

        def <<(datagram)
          current_flush_initiated_time = Time.now
          invalidate_socket_and_retry_if_error do
            @number_of_requests_attempted += 1
            response = make_request(datagram)
            if ["201", "200"].include?(response.code)
              @number_of_requests_succeeded += 1
            else
              StatsD.logger.warn do
                "[#{self.class.name}] Events were dropped because of response code from Prometheus: #{response.code}"
              end
            end
          end
          @last_flush_initiated_time = current_flush_initiated_time
          self
        end

        def failed_to_push!
          @number_of_metrics_dropped_due_to_buffer_full += 1
        end

        private

        def request_body(datagram)
          aggregator = StatsD::Instrument::Prometheus::Aggregator.new(datagram, percentiles)
          aggregated = aggregator.run
          aggregated_with_flush_stats = StatsD::Instrument::Prometheus::FlushStats.new(
            aggregated,
            default_tags,
            aggregator.pre_aggregation_number_of_metrics,
            number_of_requests_attempted,
            number_of_requests_succeeded,
            number_of_metrics_dropped_due_to_buffer_full,
            last_flush_initiated_time,
            aggregator.number_of_metrics_failed_to_parse,
          ).run
          serialized = StatsD::Instrument::Prometheus::Serializer.new(
            aggregated_with_flush_stats,
            application_name,
            subsystem,
          ).run
          Snappy.deflate(serialized)
        end

        def make_request(datagram)
          request = Net::HTTP::Post.new(uri.request_uri)
          if basic_auth_user
            request.basic_auth(basic_auth_user, auth_key)
          else
            request["Authorization"] = "Bearer #{auth_key}"
          end
          request.body = request_body(datagram)
          socket.request(request)
        end

        def build_socket
          socket = Net::HTTP.new(uri.host, uri.port)
          socket.open_timeout = open_timeout
          socket.read_timeout = read_timeout
          socket.write_timeout = write_timeout
          socket.use_ssl = true
          socket.start
          socket
        end
      end
    end
  end
end
