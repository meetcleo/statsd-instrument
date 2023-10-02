# frozen_string_literal: true

module StatsD
  module Instrument
    # @note This class is part of the new Client implementation that is intended
    #   to become the new default in the next major release of this library.
    class Buffer < SizedQueue
      def push_nonblock(item)
        push(item, true)
      rescue ThreadError, ClosedQueueError
        nil
      end

      def inspect
        "<#{self.class.name}:#{object_id} capacity=#{max} size=#{size}>"
      end

      def pop_nonblock
        pop(true)
      rescue ThreadError
        nil
      end
    end
  end
end
