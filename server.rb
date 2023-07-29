# frozen_string_literal: true
require "sinatra"
require "sinatra/reloader" if development?
require "./apple_music/client.rb"

require "debug"

get "/authorize" do
  @developer_token = AppleMusic::Client.authentication_token
  erb :"authorize/index"
end

post "/authorize" do
  file = File.open("music_user_token.json", "w") { |f| f.write request.body.read }
  Sinatra::Application.quit!
end

run Sinatra::Application.run!
