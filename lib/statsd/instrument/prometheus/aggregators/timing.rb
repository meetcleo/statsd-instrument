# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      module Aggregators
        # Borrowed from: https://github.com/statsd/statsd/blob/master/lib/process_metrics.js#L22
        # Read more about the format here: https://github.com/statsd/statsd/blob/master/docs/metric_types.md#timing
        class Timing < Base
          def aggregate
            current_timer_data = {}
            current_timer_count_data = {}
            values = datagrams.map(&:value).sort
            count = values.length
            min = values.first

            cumulative_values = [min]
            for i in 1..(count - 1) do # rubocop:disable Style/for
              cumulative_values.push(values[i] + cumulative_values[i - 1])
            end

            sum = min
            percentiles.each do |percentile_threshold|
              count_within_percentile_threshold = count.to_f

              if count > 1
                count_within_percentile_threshold = (percentile_threshold.abs / 100.0 * count).round
                next if count_within_percentile_threshold == 0

                sum = if percentile_threshold > 0
                  cumulative_values[count_within_percentile_threshold - 1]
                else
                  cumulative_values[count - 1] - cumulative_values[count - count_within_percentile_threshold - 1]
                end
              end

              clean_percentile_threshold = percentile_threshold.to_s
              clean_percentile_threshold = clean_percentile_threshold.gsub(".", "_").gsub("-", "top")
              current_timer_count_data["count_" + clean_percentile_threshold] = count_within_percentile_threshold.to_i
              current_timer_data["sum_" + clean_percentile_threshold] = sum
            end

            sum = cumulative_values[count - 1]
            current_timer_count_data["count"] = count.to_i
            current_timer_data["sum"] = sum

            last_datagram = datagrams.last
            output = current_timer_data.map do |name, value|
              DogStatsDDatagram.new(
                DogStatsDDatagramBuilder.new.ms(
                  "#{last_datagram.name}.#{name}",
                  value,
                  last_datagram.sample_rate,
                  last_datagram.tags,
                ),
              )
            end
            output + current_timer_count_data.map do |name, value|
              DogStatsDDatagram.new(
                DogStatsDDatagramBuilder.new.c(
                  "#{last_datagram.name}.#{name}",
                  value,
                  last_datagram.sample_rate,
                  last_datagram.tags,
                ),
              )
            end
          end

          private

          def percentiles
            options[:percentiles] || []
          end
        end
      end
    end
  end
end
