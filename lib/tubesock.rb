require "tubesock/version"
require "tubesock/hijack" if defined?(ActiveSupport)
require "websocket"

# Easily interact with WebSocket connections over Rack.
# TODO: Example with pure Rack
class Tubesock
  HijackNotAvailable = Class.new RuntimeError

  def initialize(socket, version)
    @socket     = socket
    @version    = version

    @open_handlers    = []
    @message_handlers = []
    @close_handlers   = []
  end

  def self.hijack(env)
    if env['rack.hijack']
      env['rack.hijack'].call
      socket = env['rack.hijack_io']

      handshake = WebSocket::Handshake::Server.new
      handshake.from_rack env

      socket.write handshake.to_s

      self.new socket, handshake.version
    else
      raise Tubesock::HijackNotAvailable
    end
  end

  def send_data data, type = :text
    frame = WebSocket::Frame::Outgoing::Server.new(
      version: @version,
      data: data,
      type: type
    )
    @socket.write frame.to_s
  rescue IOError, Errno::EPIPE
    close
  end

  def onopen(&block)
    @open_handlers << block
  end

  def onmessage(&block)
    @message_handlers << block
  end

  def onclose(&block)
    @close_handlers << block
  end

  def listen
    keepalive
    Thread.new do
      Thread.current.abort_on_exception = true
      @open_handlers.each(&:call)
      each_frame do |data|
        @message_handlers.each{|h| h.call(data) }
      end
      close
    end
  end

  def close
    @close_handlers.each(&:call)
    @socket.close unless closed?
  end

  def closed?
    return @socket.closed? if @socket.respond_to?(:closed)
    return @socket.to_io.closed?.to_s @socket.respond_to?(:to_io) && @socket.to_io.respond_to?(:closed?)
    true
  end

  def keepalive
    thread = Thread.new do
      Thread.current.abort_on_exception = true
      loop do
        sleep 5
        send_data nil, :ping
      end
    end

    onclose do
      thread.kill
    end
  end

  private
  def each_frame
    framebuffer = WebSocket::Frame::Incoming::Server.new(version: @version)
    while IO.select([@socket])
      if(@socket.respond_to?(:readpartial) && @socket.respond_to?(:peeraddr))
        data, addrinfo = @socket.readpartial(2000), @socket.peeraddr
      else
        data, addrinfo = @socket.recvfrom(2000)
      end

      break if data.empty?
      framebuffer << data
      while frame = framebuffer.next
        case frame.type
        when :close
          return
        when :text, :binary
          yield frame.data
        end
      end
    end

  rescue Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Errno::ECONNRESET, IOError, Errno::EBADF
    nil # client disconnected or timed out
  end
end
