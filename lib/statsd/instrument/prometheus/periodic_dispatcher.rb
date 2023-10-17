# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      # The main Dispatcher is constantly dispatching, which is cool if
      # you have a local statsd server. However, sending to a Prometheus
      # instance we don't own, we shouldn't slam their API, so this will
      # send if the buffer is filling up, or we haven't sent metrics for a minute
      class PeriodicDispatcher < ::StatsD::Instrument::Dispatcher
        def initialize(host, port, buffer_capacity, thread_priority, max_packet_size, sink, seconds_to_sleep,
          seconds_between_flushes, max_fill_ratio)
          @seconds_to_sleep = seconds_to_sleep
          @seconds_between_flushes = seconds_between_flushes
          @max_fill_ratio = max_fill_ratio
          super(host, port, buffer_capacity, thread_priority, max_packet_size, sink)
        end

        def <<(datagram)
          if pushed?(datagram)
            return self unless above_max_fill_ratio?

            begin
              @dispatcher_thread.wakeup
            rescue => e
              StatsD.logger.warn { "[#{self.class.name}] Failed to wakeup dispatcher thread with: #{e.message}" }
            end
          else
            @udp_sink.failed_to_push!
          end

          self
        end

        private

        attr_reader :seconds_to_sleep, :seconds_between_flushes, :max_fill_ratio

        def above_max_fill_ratio?
          @buffer.size / @buffer.max.to_f > max_fill_ratio
        end

        # Base behaviour flushes until shutdown, whereas we flush periodically
        def nothing_left_to_flush?(_)
          @buffer.empty?
        end

        def time_to_flush?(last_flush)
          seconds_since_last_flush = Time.now - last_flush
          above_max_fill_ratio? || seconds_since_last_flush >= seconds_between_flushes
        end

        def dispatch
          last_flush = Time.now
          until @interrupted
            sleep(seconds_to_sleep)

            next unless time_to_flush?(last_flush)

            begin
              last_flush = Time.now
              flush(blocking: true)
            rescue => error
              report_error(error)
            end
          end

          flush(blocking: false)
        end
      end
    end
  end
end
