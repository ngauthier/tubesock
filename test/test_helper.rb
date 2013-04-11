require 'bundler/setup'
require 'minitest/autorun'
require 'simplecov'
SimpleCov.start

require 'tubesock'

class Tubesock::TestCase < MiniTest::Unit::TestCase
end
