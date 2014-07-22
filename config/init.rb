require 'sinatra'
require 'sinatra/sequel'
require 'sequel'
require 'zero_push'

configure do
  DB = Sequel.connect(ENV['DATABASE_URL'])
  require './config/migrations'
  require './config/data'
end

use Rack::Auth::Basic do |username, password|
  username == ENV['AUTH_USER'] && password == ENV['AUTH_PASSWORD']
end  

configure :production do
  ZeroPush.auth_token = ENV["ZEROPUSH_PROD_TOKEN"]
end

configure :development do
  require 'logger'
  DB.logger = Logger.new($stdout)
  ZeroPush.auth_token = ENV["ZEROPUSH_DEV_TOKEN"]
end
 
