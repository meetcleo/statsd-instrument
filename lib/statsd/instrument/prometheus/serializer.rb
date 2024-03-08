# frozen_string_literal: true

module StatsD
  module Instrument
    module Prometheus
      class Serializer
        # Colon separated, but allows double-colon values, e.g. name:value, name.1:value.1, name:Module1::Module2::Class
        LABEL_EXTRACTOR = /^(?<name>[^\:]+)\:(?<value>.+)$/
        INVALID_NAME_CHARACTERS = /[^a-zA-Z0-9:_]/

        def initialize(datagrams, application_name, subsystem, dyno_number, worker_index)
          @datagrams = datagrams
          @current_time_ms = (Time.now.to_f * 1000).to_i
          @dyno_number = dyno_number
          @worker_index = worker_index
          @application_name = application_name
          @subsystem = subsystem
        end

        def run
          ::Prometheus::WriteRequest.encode(::Prometheus::WriteRequest.new(timeseries: timeseries, metadata: []))
        end

        class << self
          def cleanse_name(name)
            name.gsub(INVALID_NAME_CHARACTERS, "_")
          end
        end

        private

        attr_reader :datagrams, :current_time_ms, :dyno_number, :worker_index, :application_name, :subsystem

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
            labels["dyno_number"] = ::Prometheus::Label.new(name: "dyno_number", value: dyno_number) if dyno_number
            labels["worker_index"] = ::Prometheus::Label.new(name: "worker_index", value: worker_index) if worker_index
          end
        end

        # This will prevent dup labels
        def labels_by_name(datagram)
          labels = default_prometheus_labels.clone
          labels["__name__"] = ::Prometheus::Label.new(name: "__name__", value: self.class.cleanse_name(datagram.name))
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
