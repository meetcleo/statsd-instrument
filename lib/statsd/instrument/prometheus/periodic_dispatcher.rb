# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      # The main Dispatcher is constantly dispatching, which is cool if
      # you have a local statsd server. However, sending to a Prometheus
      # instance we don't own, we shouldn't slam their API, so this will
      # send if the buffer is filling up, or we haven't sent metrics for a minute
      class PeriodicDispatcher < ::StatsD::Instrument::Dispatcher
        SECONDS_TO_SLEEP = 1 # Check if the buffer needs flushing every second
        SECONDS_BETWEEN_FLUSHES = 60
        MAX_FILL_RATIO = 0.8 # Flush the buffer if it is over 80% full

        def <<(datagram)
          result = super

          return result unless above_max_fill_ratio?

          begin
            @dispatcher_thread.wakeup
          rescue => e
            StatsD.logger.warn { "[#{self.class.name}] Failed to wakeup dispatcher thread with: #{e.message}" }
          end

          result
        end

        private

        def above_max_fill_ratio?
          @buffer.size / @buffer.max.to_f > MAX_FILL_RATIO
        end

        # Base behaviour flushes until shutdown, whereas we flush periodically
        def nothing_left_to_flush?(_)
          @buffer.empty?
        end

        def time_to_flush?(last_flush)
          seconds_since_last_flush = Time.now - last_flush
          above_max_fill_ratio? || seconds_since_last_flush >= SECONDS_BETWEEN_FLUSHES
        end

        def dispatch
          last_flush = Time.now
          until @interrupted
            sleep(SECONDS_TO_SLEEP)

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
