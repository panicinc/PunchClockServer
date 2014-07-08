require 'bundler'
Bundler.require

$stdout.sync = true

require './my_app'

run Sinatra::Application
