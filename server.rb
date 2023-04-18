# frozen_string_literal: true
require "sinatra"
require "sinatra/reloader" if development?
require "./apple/music_client.rb"

require "debug"

get "/authorize" do
  @developer_token = Apple::MusicClient.authentication_token
  erb :"authorize/index"
end

post "/authorize" do
  file = File.open("music_user_token.json", "w") { |f| f.write request.body.read }
  Sinatra::Application.quit!
end

run Sinatra::Application.run!
