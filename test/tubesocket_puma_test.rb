require_relative './test_helper'
require 'puma'
require 'puma/minissl'

class MockEngine
  def read; "data" end
  def inject(data); end
  def extract; end
  def init?; true; end
  def write(data)
    1
  end
end

class MockSocket < IO
  def initialize; end
  def close; end
  def closed?; false; end
  def readpartial(len); end
end

class Puma::MiniSSL::Socket
  def initialize
    @socket = MockSocket.new
    @engine = MockEngine.new
  end
end

class TubesockPumaTest < Tubesock::TestCase
  def test_integration
    socket = Puma::MiniSSL::Socket.new

    interaction = TestInteraction.new(socket)

    proc { interaction.close }.must_raise NoMethodError

    proc { interaction.read }.must_raise NoMethodError

    interaction.tubesock do |tubesock|
      proc { tubesock.close }.must_be_silent
    end

  end
end
