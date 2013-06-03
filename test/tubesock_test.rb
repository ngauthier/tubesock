require 'test_helper'

# Force autoloading of classes
WebSocket::Frame::Incoming::Client
WebSocket::Frame::Outgoing::Client
WebSocket::Frame::Incoming::Server
WebSocket::Frame::Outgoing::Server

class TubesockTest < Tubesock::TestCase

  def test_raise_exception_when_hijack_is_not_available
    -> {
      Tubesock.hijack({})
    }.must_raise Tubesock::HijackNotAvailable
  end

  def test_hijack
    interaction = TestInteraction.new

    opened = MockProc.new
    closed = MockProc.new

    interaction.tubesock do |tubesock|
      tubesock.onopen  &opened
      tubesock.onclose &closed

      tubesock.onmessage do |message|
        tubesock.send_data message: "Hello #{message["name"]}"
      end
    end

    interaction.write name: "Nick"
    data = interaction.read
    data["message"].must_equal "Hello Nick"
    interaction.close

    opened.called.must_equal true
    closed.called.must_equal true
  end

  def test_hijack_invalid_json_from_client
    interaction = TestInteraction.new

    closed = MockProc.new

    interaction.tubesock do |tubesock|
      tubesock.onclose &closed

      tubesock.onmessage do |message|
      end
    end

    # That's what Firefox sends when disconnecting.
    interaction.write_raw "\x88\x82\xA3\x95\xD5\xB1\xA0|".force_encoding('binary')

    interaction.join

    closed.called.must_equal true
  end
end
