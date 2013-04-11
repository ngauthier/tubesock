require 'test_helper'

describe Tubesock do
  it "must raise an exception when rack.hijack is not available" do
    -> {
      Tubesock.hijack({})
    }.must_raise Tubesock::HijackNotAvailable
  end

  it "can hijack rack and send frames" do
    client_io, server_io = UNIXSocket.pair

    client = WebSocket::Handshake::Client.new(:url => 'ws://example.com')

    request = WEBrick::HTTPRequest.new( :ServerSoftware => "" )
    request.parse(StringIO.new(client.to_s)).must_equal true
    rest    = client.to_s.slice((request.to_s.length..-1))

    sock = Tubesock.hijack(request.meta_vars.merge(
      "rack.input" => StringIO.new(rest),
      "rack.hijack" => proc {},
      "rack.hijack_io" => server_io
    ))
    sock.listen
    # read the handshake to clear the socket
    client_io.recvfrom(2000)

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

    frame = WebSocket::Frame::Outgoing::Client.new(
      version: client.version,
      data:    JSON.dump(name: "Nick"),
      type:    :text
    )

    client_io << frame.to_s

    t = Thread.new do
      Thread.current.abort_on_exception = true
      framebuffer = WebSocket::Frame::Incoming::Client.new(version: client.version)
      data, addrinfo = client_io.recvfrom(2000)
      framebuffer << data

      frame = framebuffer.next

      frame.wont_be_nil
      JSON.load(frame.data)["message"].must_equal "Hello Nick"
      client_io.close
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
