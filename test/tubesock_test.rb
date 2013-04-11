require 'test_helper'

describe Tubesock do
  it "must raise an exception when rack.hijack is not available" do
    -> {
      Tubesock.hijack({})
    }.must_raise Tubesock::HijackNotAvailable
  end

  it "can hijack rack and send frames simply" do
    interaction = Tubesock::TestInteraction.new

    sock = interaction.tubesock

    opened = false
    closed = false

    sock.onopen do
      opened = true
    end

    sock.onclose do
      closed = true
    end

    sock.onmessage do |message|
      sock.send_data(message: "Hello #{message["name"]}")
    end

    interaction.write name: "Nick"

    t = Thread.new do
      Thread.current.abort_on_exception = true
      data = interaction.read
      data["message"].must_equal "Hello Nick"
      interaction.close
    end

    t.join

    Timeout::timeout(5) do
      while !closed || !opened
      end
    end

    opened.must_equal true
    closed.must_equal true
  end
end
