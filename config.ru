require 'sinatra'
require 'sinatra/contrib'
require 'pry'
require 'sinatra/reloader'
require 'rest-client'
require_relative 'forum'

use Rack::MethodOverride
run Forum::Server