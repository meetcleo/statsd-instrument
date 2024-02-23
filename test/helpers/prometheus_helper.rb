# frozen_string_literal: true

module PrometheusHelper
  def inflate_and_decode(body)
    result = ::Prometheus::WriteRequest.decode(Snappy.inflate(body))
    result.timeseries.entries.each do |timeseries|
      timeseries.samples.entries.each do |sample|
        sample.timestamp = -1 # Timecop not working for multithreaded stuff
      end
      timeseries.samples.entries.each do |sample|
        sample.value = -1 # Timecop not working for multithreaded stuff
      end if timeseries.labels.entries.map(&:value).include?("time_since_last_flush_initiated")
    end
    result
  end

  def assert_request_contents(url, expected_body, expected_headers: {}, times: 1)
    assert_requested(:post, url, times: times) do |request|
      if expected_body
        actual_body = inflate_and_decode(request.body)
        assert_equal(expected_body, actual_body.to_h, "request body did not match expected")
      end
      expected_headers.each do |key, expected_value|
        assert_equal(expected_value, request.headers[key], "header `#{key}` did not match expected")
      end
    end
  end
end
