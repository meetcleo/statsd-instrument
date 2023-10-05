# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      module Aggregators
        # Borrowed from: https://github.com/statsd/statsd/blob/master/lib/process_metrics.js#L22
        # Read more about the format here: https://github.com/statsd/statsd/blob/master/docs/metric_types.md#timing
        class Timing < Base
          def aggregate
            current_timer_data = { }
            current_timer_count_data = { }
            values = datagrams.map(&:value).sort
            count = values.length
            min = values.first
            max = values.last

            cumulative_values = [min]
            cumulative_sum_squares_values = [min * min]
            for i in 1..(count - 1) do
              cumulative_values.push(values[i] + cumulative_values[i-1])
              cumulative_sum_squares_values.push((values[i] * values[i]) + cumulative_sum_squares_values[i - 1])
            end

            sum = min
            sum_squares = min * min
            mean = min
            threshold_boundary = max

            percentiles.each do |percentile_threshold|
              count_within_percentile_threshold = count.to_f

              if (count > 1)
                count_within_percentile_threshold = (percentile_threshold.abs / 100.0 * count).round
                next if count_within_percentile_threshold == 0

                if (percentile_threshold > 0)
                  threshold_boundary = values[count_within_percentile_threshold - 1]
                  sum = cumulative_values[count_within_percentile_threshold - 1]
                  sum_squares = cumulative_sum_squares_values[count_within_percentile_threshold - 1]
                else
                  threshold_boundary = values[count - count_within_percentile_threshold]
                  sum = cumulative_values[count - 1] - cumulative_values[count - count_within_percentile_threshold - 1]
                  sum_squares = cumulative_sum_squares_values[count - 1] - cumulative_sum_squares_values[count - count_within_percentile_threshold - 1]
                end
                mean = sum / count_within_percentile_threshold
              end

              clean_percentile_threshold = percentile_threshold.to_s
              clean_percentile_threshold = clean_percentile_threshold.gsub('.', '_').gsub('-', 'top')
              current_timer_count_data["count_" + clean_percentile_threshold] = count_within_percentile_threshold
              current_timer_data["mean_" + clean_percentile_threshold] = mean
              current_timer_data[(percentile_threshold > 0 ? "upper_" : "lower_") + clean_percentile_threshold] = threshold_boundary
              current_timer_data["sum_" + clean_percentile_threshold] = sum
              current_timer_data["sum_squares_" + clean_percentile_threshold] = sum_squares
            end

            sum = cumulative_values[count - 1]
            sum_squares = cumulative_sum_squares_values[count - 1]
            mean = sum / count.to_f

            sum_of_diffs = 0;
            for i in 0..(count - 1) do
               sum_of_diffs += (values[i] - mean) * (values[i] - mean)
            end

            mid = (count / 2.0).floor
            median = (count % 2) ? values[mid] : (values[mid - 1] + values[mid]) / 2.0

            stddev = Math.sqrt(sum_of_diffs / count.to_f)
            current_timer_data["std"] = stddev
            current_timer_data["upper"] = max
            current_timer_data["lower"] = min
            current_timer_count_data["count"] = count
            # current_timer_data["count_ps"] = count / (flushInterval / 1000.0)
            current_timer_data["sum"] = sum
            current_timer_data["sum_squares"] = sum_squares
            current_timer_data["mean"] = mean
            current_timer_data["median"] = median

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
            output +  current_timer_count_data.map do |name, value|
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