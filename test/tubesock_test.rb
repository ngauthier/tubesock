require 'test_helper'

describe Tubesock do
  it "must raise an exception when rack.hijack is not available" do
    -> {
      Tubesock.hijack({})
    }.must_raise Tubesock::HijackNotAvailable
  end
end
