# frozen_string_literal: true

require "snappy"
require "httpx"

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
          :basic_auth_user,
          :histograms,
          :dyno_number,
          :worker_index

        def initialize(addr, auth_key, percentiles, application_name, subsystem, default_tags, open_timeout, read_timeout, write_timeout, basic_auth_user, histograms, dyno_number, worker_index) # rubocop:disable Lint/MissingSuper
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
          @histograms = histograms
          @dyno_number = dyno_number
          @worker_index = worker_index
        end

        def <<(datagram)
          current_flush_initiated_time = Time.now
          invalidate_socket_and_retry_if_error do
            @number_of_requests_attempted += 1
            response = make_request(datagram)
            if [201, 200].include?(response.status)
              @number_of_requests_succeeded += 1
            else
              StatsD.logger.warn do
                "[#{self.class.name}] Events were dropped because of response status from Prometheus: #{response.status}"
              end
              response.raise_for_status # https://honeyryderchuck.gitlab.io/httpx/wiki/Error-Handling#error-pattern-matching
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
          aggregator = StatsD::Instrument::Prometheus::Aggregator.new(datagram, percentiles, histograms)
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
            dyno_number,
            worker_index,
          ).run
          Snappy.deflate(serialized)
        end

        def make_request(datagram)
          socket.post(uri.request_uri, body: request_body(datagram))
        end

        def build_socket
          socket = if basic_auth_user
            HTTPX
              .plugin(:basic_auth)
              .basic_auth(basic_auth_user, auth_key)
          else
            HTTPX
              .plugin(:auth)
              .bearer_auth(auth_key)
          end

          socket
            .with(origin: uri.origin)
            .with(timeout: { connect_timeout: open_timeout, write_timeout: write_timeout, read_timeout: read_timeout })
        end
      end
    end
  end
end
