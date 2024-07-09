# frozen_string_literal: true

require "test_helper"
require "webmock"
require "httpx/adapters/webmock"
require "webmock/minitest"

module Prometheus
  class IntegrationTest < Minitest::Test
    include ::PrometheusHelper
    TEST_URL = "https://www.example.com/"

    def setup
      @env = StatsD::Instrument::Environment.new(
        "STATSD_ADDR" => TEST_URL,
        "STATSD_IMPLEMENTATION" => "dogstatsd",
        "STATSD_ENV" => "production",
        "STATSD_PROMETHEUS_AUTH" => "abc",
        "STATSD_DEFAULT_TAGS" => "env:test",
        "STATSD_PROMETHEUS_APPLICATION_NAME" => "app-name",
        "STATSD_PROMETHEUS_SUBSYSTEM" => "subsystem",
        "DYNO" => "web.1",
        "WORKER_INDEX" => "0",
      )

      @old_client = StatsD.singleton_client
      StatsD.singleton_client = @env.client
    end

    def teardown
      StatsD.singleton_client = @old_client
    end

    def expected_metric(name, value, additional_labels: [])
      {
        labels: [
          { name: "__meta_applicationname", value: "app-name" },
          { name: "__meta_subsystem", value: "subsystem" },
          { name: "dyno_number", value: "1" },
          { name: "worker_index", value: "0" },
          { name: "__name__", value: name },
          { name: "env", value: "test" },
        ] + additional_labels,
        samples: [
          { value: value, timestamp: -1 },
        ],
        exemplars: [],
      }
    end

    def test_mocked_request
      expected = {
        timeseries: [
          {
            labels: [
              { name: "__meta_applicationname", value: "app-name" },
              { name: "__meta_subsystem", value: "subsystem" },
              { name: "dyno_number", value: "1" },
              { name: "worker_index", value: "0" },
              { name: "__name__", value: "counter_total" },
              { name: "source", value: "App::Main::Controller" },
              { name: "env", value: "test" },
            ],
            samples: [
              { value: 2.0, timestamp: -1 },
            ],
            exemplars: [],
          },
          {
            labels: [
              { name: "__meta_applicationname", value: "app-name" },
              { name: "__meta_subsystem", value: "subsystem" },
              { name: "dyno_number", value: "1" },
              { name: "worker_index", value: "0" },
              { name: "__name__", value: "will_fail_total" },
              { name: "source", value: "App::Main::Controller" },
              { name: "env", value: "test" },
            ],
            samples: [
              { value: 1.0, timestamp: -1 },
            ],
            exemplars: [],
          },
          expected_metric("metrics_since_last_flush", 2.0),
          expected_metric("pre_aggregation_number_of_metrics_since_last_flush", 4.0),
          expected_metric("number_of_requests_attempted_total", 1.0),
          expected_metric("number_of_requests_succeeded_upto_previous_flush_total", 0.0),
          expected_metric("number_of_metrics_dropped_due_to_buffer_full_total", 0.0),
          expected_metric("time_since_last_flush_initiated", -1),
          expected_metric("number_of_metrics_dropped_due_to_parsing_failure_total", 1.0),
        ],
        metadata: [],
      }
      stub_request(:post, TEST_URL).to_return(status: 201)
      StatsD.increment("counter", tags: { source: "App::Main::Controller", dyno_number: "1", worker_index: "0" })
      StatsD.increment("counter", tags: { source: "App::Main::Controller", dyno_number: "1", worker_index: "0" })
      # Will treat the newline as its own metric that will fail to parse
      StatsD.increment(":\nwill_fail", tags: { source: "App::Main::Controller", dyno_number: "1", worker_index: "0" })
      StatsD.singleton_client.sink.shutdown
      assert_request_contents(TEST_URL, expected, expected_headers: { "Authorization" => "Bearer abc" })
    end
  end
end
