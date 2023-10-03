# frozen_string_literal: true

require "test_helper"

module Prometheus
  class SerializerTest < Minitest::Test
    def setup
      @serializer = StatsD::Instrument::Prometheus::Serializer.new
    end

    def test_run
      assert_equal("foo", @serializer.send(:run, "foo"))
      assert_equal("fo_o", @serializer.send(:run, "fo|o"))
      assert_equal("fo_o", @serializer.send(:run, "fo@o"))
      assert_equal("fo_o", @serializer.send(:run, "fo:o"))
    end
  end
end