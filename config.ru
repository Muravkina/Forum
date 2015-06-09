require 'rubygems'
require 'bundler'

Bundler.require(:default, ENV['RACK_ENV'] || 'development')

use Rack::MethodOverride
require_relative 'forum'

run Forum::Server




