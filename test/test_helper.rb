require 'bundler/setup'
require 'minitest/autorun'
require 'simplecov'
require 'webrick'
SimpleCov.start
require 'tubesock'

class Tubesock::TestCase < MiniTest::Unit::TestCase
  def wait
    Timeout::timeout(5) do
      while !yield
        sleep 0.001
      end
    end
  end
end

# Abstrack away frames and sockets so that
# tests can focus on message interaction
class Tubesock::TestCase::TestInteraction
  def initialize
    @client_socket, @server_socket = UNIXSocket.pair
  end

  def handshake
    @handshake ||= WebSocket::Handshake::Client.new(:url => 'ws://example.com')
  end

  def version
    handshake.version
  end

  def env
    request = WEBrick::HTTPRequest.new( :ServerSoftware => "" )
    request.parse(StringIO.new(handshake.to_s))
    rest = handshake.to_s.slice((request.to_s.length..-1))

    request.meta_vars.merge(
      "rack.input" => StringIO.new(rest),
      "rack.hijack" => proc {},
      "rack.hijack_io" => @server_socket
    )
  end

  def write(message)
    @client_socket << WebSocket::Frame::Outgoing::Client.new(
      version: version,
      data:    JSON.dump(message),
      type:    :text
    ).to_s
  end

  def read
    framebuffer = WebSocket::Frame::Incoming::Client.new(version: version)
    data, addrinfo = @client_socket.recvfrom(2000)
    framebuffer << data
    JSON.load(framebuffer.next.data)
  end

  def close
    @client_socket.close
  end

  def tubesock
    tubesock = Tubesock.hijack(env)
    tubesock.listen
    @client_socket.recvfrom 2000 # flush the handshake
    tubesock
  end
end

def Tubesock::TestPair
  client_io, server_io = UNIXSocket.pair
  client = Tubesock::TestClient.new(client_io)
  server = Tubesock::TestServer.new(server_io)
  [client, server]
end
