require 'rubygems'
require 'bundler'

Bundler.require(:default, ENV['RACK_ENV'] || 'development')

require_relative 'forum'
use Rack::MethodOverride

run Forum::Server




