require "tubesock/version"
require "tubesock/hijack" if defined?(Rails)

class Tubesock
  def initialize(socket, version)
    @socket     = socket
    @version    = version
  end

  def self.call(env)
    if websocket?(env)
      tubesock = hijack(env)
      tubesock.listen
      [ -1, {}, [] ]
    else
      [404, {'Content-Type' => 'text/plain'}, ['Not Found']]
    end
  end

  def self.hijack(env)
    env['rack.hijack'].call
    socket = env['rack.hijack_io']

    handshake = WebSocket::Handshake::Server.new
    handshake.headers["sec-websocket-version"]    = env["HTTP_SEC_WEBSOCKET_VERSION"]
    handshake.headers["sec-websocket-draft"]      = env["HTTP_SEC_WEBSOCKET_DRAFT"]
    handshake.headers["sec-websocket-key"]        = env["HTTP_SEC_WEBSOCKET_KEY"]
    handshake.headers["sec-websocket-extensions"] = env["HTTP_SEC_WEBSOCKET_EXTENSIONS"]
    handshake.headers["host"]                     = env["HTTP_HOST"]
    handshake.path                                = env["REQUEST_PATH"]
    handshake.query                               = env["QUERY_STRING"]
    handshake.set_version

    socket.write handshake.to_s

    self.new socket, handshake.version
  end

  def self.websocket?(env)
    env['REQUEST_METHOD'] == 'GET' and
    env['HTTP_CONNECTION'] and
    env['HTTP_CONNECTION'].split(/\s*,\s*/).include?('Upgrade') and
    env['HTTP_UPGRADE'].downcase == 'websocket'
  end

  def send_data data, type = :text
    frame = WebSocket::Frame::Outgoing::Server.new(version: @version, data: JSON.dump(data), type: type)
    @socket.write frame.to_s
  rescue IOError
    close
  end

  def onopen(&block)
    @openhandler = block
  end

  def onmessage(&block)
    @messagehandler = block
  end

  def onclose(&block)
    @closehandler = block
  end

  def listen
    Thread.new do
      Thread.current.abort_on_exception = true
      framebuffer = WebSocket::Frame::Incoming::Server.new(version: @version)
      running = true
      while running
        data, addrinfo = @socket.recvfrom(2000)
        running = false if data == ""
        framebuffer << data
        while frame = framebuffer.next
          data = frame.data
          if data == ""
            running = false
          else
            @messagehandler.call(HashWithIndifferentAccess.new(JSON.load(data))) if @messagehandler
          end
        end
      end
      @closehandler.call if @closehandler
      @socket.close
    end
    @openhandler.call if @openhandler
  end

  def close
    @socket.close if @socket.open?
    @closehandler.call
  end
end
