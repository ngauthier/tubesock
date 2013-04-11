require 'test_helper'

class TubesockTest < Tubesock::TestCase

  def test_raise_exception_when_hijack_is_not_available
    -> {
      Tubesock.hijack({})
    }.must_raise Tubesock::HijackNotAvailable
  end

  def test_hijack
    interaction = TestInteraction.new

    sock = interaction.tubesock

    opened = false
    closed = false

    sock.onopen  { opened = true }
    sock.onclose { closed = true }

    sock.onmessage do |message|
      sock.send_data message: "Hello #{message["name"]}"
    end

    interaction.write name: "Nick"

    data = interaction.read
    data["message"].must_equal "Hello Nick"
    interaction.close

    wait { closed && opened }
  end
end
