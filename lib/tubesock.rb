require "tubesock/version"
require "tubesock/hijack" if defined?(Rails)
require "websocket"

class Tubesock
  class HijackNotAvailable < RuntimeError
  end

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
    frame = WebSocket::Frame::Outgoing::Server.new(version: @version, data: JSON.dump(data), type: type)
    @socket.write frame.to_s
  rescue IOError
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
    Thread.new do
      Thread.current.abort_on_exception = true
      framebuffer = WebSocket::Frame::Incoming::Server.new(version: @version)
      @open_handlers.each(&:call)
      while !@socket.closed?
        data, addrinfo = @socket.recvfrom(2000)
        break if data.empty?
        framebuffer << data
        while frame = framebuffer.next
          data = frame.data
          @message_handlers.each{|h| h.call(JSON.load(data)) }
        end
      end
      @close_handlers.each(&:call)
      @socket.close
    end
  end
end
