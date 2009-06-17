require 'rubygems'
require 'test/unit'
require 'ostruct'
require 'fake_door'

require 'player'

gem 'thoughtbot-shoulda'
gem 'jferris-mocha'
require 'shoulda'
require 'mocha'

WIN32OLE             = Class.new                unless Object.const_defined?("WIN32OLE")
WIN32OLERuntimeError = Class.new(StandardError) unless Object.const_defined?("WIN32OLERuntimeError")
