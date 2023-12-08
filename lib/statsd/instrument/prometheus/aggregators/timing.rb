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

            calculate_percentiles(count, cumulative_values, current_timer_data, current_timer_count_data)
            calculate_base(count, cumulative_values, current_timer_data, current_timer_count_data)
            current_timer_histogram_buckets = calculate_histograms(values)

            last_datagram = datagrams.last
            timer_data_to_datagrams(current_timer_data, last_datagram) +
              timer_count_data_to_datagrams(current_timer_count_data, last_datagram) +
              timer_histogram_data_to_datagrams(current_timer_histogram_buckets, last_datagram)
          end

          private

          def calculate_base(count, cumulative_values, current_timer_data, current_timer_count_data)
            sum = cumulative_values[count - 1]
            current_timer_count_data["count"] = count.to_i
            current_timer_data["sum"] = sum
          end

          def calculate_percentiles(count, cumulative_values, current_timer_data, current_timer_count_data)
            sum = cumulative_values[0]
            percentiles.sort.each do |percentile_threshold|
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
          end

          def calculate_histograms(values)
            result = histograms.sort.each_with_object({}) do |bucket, current_timer_histograms|
              current_timer_histograms[bucket] = values.select { |value| value <= bucket }.count
            end
            result["+Inf"] = values.count if histograms.any?
            result
          end

          def timer_data_to_datagrams(current_timer_data, last_datagram)
            current_timer_data.map do |name, value|
              DogStatsDDatagram.new(
                DogStatsDDatagramBuilder.new.ms(
                  "#{last_datagram.name}.#{name}",
                  value,
                  last_datagram.sample_rate,
                  last_datagram.tags,
                ),
              )
            end
          end

          def timer_count_data_to_datagrams(current_timer_count_data, last_datagram)
            current_timer_count_data.map do |name, value|
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

          def timer_histogram_data_to_datagrams(current_timer_histogram_buckets, last_datagram)
            current_timer_histogram_buckets.map do |bucket, value|
              DogStatsDDatagram.new(
                DogStatsDDatagramBuilder.new.c(
                  "#{last_datagram.name}.bucket",
                  value,
                  last_datagram.sample_rate,
                  (last_datagram.tags || []) + ["le:#{bucket}"],
                ),
              )
            end
          end

          def percentiles
            options[:percentiles] || []
          end

          def histograms
            options[:histograms] || []
          end
        end
      end
    end
  end
end
