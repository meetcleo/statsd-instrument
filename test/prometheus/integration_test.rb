# frozen_string_literal: true

require "test_helper"
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
      )

      @old_client = StatsD.singleton_client
      StatsD.singleton_client = @env.client
    end

    def teardown
      StatsD.singleton_client = @old_client
    end

    def test_mocked_request
      expected = {
        timeseries: [
          {
            labels: [
              { name: "__meta_applicationname", value: "app-name" },
              { name: "__meta_subsystem", value: "subsystem" },
              { name: "host", value: "" },
              { name: "pid", value: "" },
              { name: "__name__", value: "counter.total" },
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
              { name: "host", value: "" },
              { name: "pid", value: "" },
              { name: "__name__", value: "metrics_since_last_flush" },
              { name: "env", value: "test" },
            ],
            samples: [
              { value: 1.0, timestamp: -1 },
            ],
            exemplars: [],
          },
          {
            labels: [
              { name: "__meta_applicationname", value: "app-name" },
              { name: "__meta_subsystem", value: "subsystem" },
              { name: "host", value: "" },
              { name: "pid", value: "" },
              { name: "__name__", value: "pre_aggregation_number_of_metrics_since_last_flush" },
              { name: "env", value: "test" },
            ],
            samples: [
              { value: 2.0, timestamp: -1 },
            ],
            exemplars: [],
          },
        ],
        metadata: [],
      }
      stub_request(:post, TEST_URL).to_return(status: 201)
      StatsD.increment("counter", tags: { source: "App::Main::Controller", host: "localhost" })
      StatsD.increment("counter", tags: { source: "App::Main::Controller", host: "localhost" })
      StatsD.singleton_client.sink.shutdown
      assert_request_contents(TEST_URL, expected, expected_headers: { "Authorization" => "Bearer abc" })
    end
  end
end
