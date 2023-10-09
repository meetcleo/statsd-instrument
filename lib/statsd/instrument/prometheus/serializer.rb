# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      class Serializer
        # Colon separated, but allows double-colon values, e.g. name:value, name.1:value.1, name:Module1::Module2::Class
        LABEL_EXTRACTOR = /^(?<name>[^\:]+)\:(?<value>.+)$/

        def initialize(datagrams, application_name, subsystem)
          @datagrams = datagrams
          @current_time_ms = (Time.now.to_f * 1000).to_i
          @pid = Process.pid&.to_s
          @hostname = Socket.gethostname
          @application_name = application_name
          @subsystem = subsystem
        end

        def run
          ::Prometheus::WriteRequest.encode(::Prometheus::WriteRequest.new(timeseries: timeseries, metadata: []))
        end

        private

        attr_reader :datagrams, :current_time_ms, :pid, :hostname, :application_name, :subsystem

        def timeseries
          datagrams.map do |datagram|
            ::Prometheus::TimeSeries.new(
              labels: labels_by_name(datagram).values,
              samples: [::Prometheus::Sample.new(timestamp: current_time_ms, value: datagram.value)],
            )
          end
        end

        def default_prometheus_labels
          @default_prometheus_labels ||= {}.tap do |labels|
            labels["__meta_applicationname"] =
              ::Prometheus::Label.new(name: "__meta_applicationname", value: application_name) if application_name
            labels["__meta_subsystem"] =
              ::Prometheus::Label.new(name: "__meta_subsystem", value: subsystem) if subsystem
            labels["host"] = ::Prometheus::Label.new(name: "host", value: hostname) if hostname
            labels["pid"] = ::Prometheus::Label.new(name: "pid", value: pid) if pid
          end
        end

        # This will prevent dup labels
        def labels_by_name(datagram)
          labels = default_prometheus_labels.clone
          labels["__name__"] = ::Prometheus::Label.new(name: "__name__", value: datagram.name)
          return labels unless datagram.tags

          extracted_labels_from_tags = datagram.tags.map do |tag|
            LABEL_EXTRACTOR.match(tag)
          end.compact.to_h do |matches|
            [matches["name"], ::Prometheus::Label.new(name: matches["name"], value: matches["value"])]
          end
          labels.merge(extracted_labels_from_tags)
        end
      end
    end
  end
end
