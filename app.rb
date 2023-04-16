# frozen_string_literal: true
require "sinatra"
require "sinatra/reloader" if development?
require "./echoes_feed.rb"
require "./apple/music_client.rb"

require "debug"

get "/" do
  @developer_token = Apple::MusicClient.authentication_token
  erb :index
  # Apple::MusicClient.get("catalog/us/charts", types: 'songs', limit: 100).body
  # EchoesFeed.get_most_recent_playlist_data.to_json
end

post "/" do
  puts request.body.read
  true
end
