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
    @error_handlers   = []

    @close_on_error = true

    @active = true
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

  def prevent_close_on_error
    @close_on_error = false
  end

  def send_data data, type = :text
    frame = WebSocket::Frame::Outgoing::Server.new(
      version: @version,
      data: data,
      type: type
    )
    @socket.write frame.to_s
  rescue IOError, Errno::EPIPE, Errno::ETIMEDOUT
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

  def onerror(&block)
    @error_handlers << block
  end

  def listen
    keepalive
    Thread.new do
      Thread.current.abort_on_exception = true
      begin
        @open_handlers.each(&:call)
        each_frame do |data|
          @message_handlers.each do |h|
            begin
              h.call(data)
            rescue => e
              @error_handlers.each{|eh| eh.call(e,data)}
              close if @close_on_error
            end
          end
        end
      ensure
        close
      end
    end
  end

  def close
    return unless @active

    @close_handlers.each(&:call)
    close!

    @active = false
  end
  
  def close!
    if @socket.respond_to?(:closed?)
      @socket.close unless @socket.closed?
    else
      @socket.close
    end
  end

  def closed?
    @socket.closed?
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
      if @socket.respond_to?(:recvfrom)
        data, addrinfo = @socket.recvfrom(2000)
      else
        data, addrinfo = @socket.readpartial(2000), @socket.peeraddr
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
