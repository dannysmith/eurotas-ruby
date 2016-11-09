require 'bundler/setup'
require 'dotenv'
require 'sinatra/base'
require 'json'

Dotenv.load

require './eurotas'

if ENV['RACK_ENV'] == 'development'
  require 'rb-readline'
  require 'pry'
end

run Eurotas::App
