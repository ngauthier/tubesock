require 'bundler/setup'
require 'simplecov'
SimpleCov.start
require 'active_support'
require 'minitest/autorun'
require 'webrick'
require 'stringio'
require 'tubesock'
require 'json'

class Tubesock::TestCase < Minitest::Unit::TestCase
end

# Abstract away frames and sockets so that
# tests can focus on message interaction
class Tubesock::TestCase::TestInteraction
  def initialize(socket = nil)
    @client_socket, @server_socket = UNIXSocket.pair
    @client_socket, @server_socket = socket, socket if socket
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

  def write_raw(message)
    @client_socket << message
  end

  def write(data)
    write_raw WebSocket::Frame::Outgoing::Client.new(
      version: version,
      data:    data,
      type:    :text
    ).to_s
  end

  def read
    framebuffer = WebSocket::Frame::Incoming::Client.new(version: version)
    data, _addrinfo = @client_socket.recvfrom(2000)
    framebuffer << data
    framebuffer.next.data
  end

  def join
    @thread.join
  end

  def close
    @client_socket.close
    join
  end

  def tubesock
    tubesock = Tubesock.hijack(env)
    yield tubesock
    @thread = tubesock.listen
    if @client_socket.respond_to?(:recvfrom)
      @client_socket.recvfrom 2000 # flush the handshake
    else
      @client_socket.readpartial 2000 # flush the handshake
    end
    tubesock
  end
end

class MockProc
  attr_reader :called
  def to_proc
    proc { @called = true }
  end
end
