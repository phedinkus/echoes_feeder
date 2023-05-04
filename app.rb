#!/usr/bin/ruby
require "sqlite3"
require "./echoes_feed.rb"
require "./apple_music/client.rb"
require "debug"

ECHOES_FOLDER_ID = "p.3VKWEkDuMeRRR"

def db
  @db ||= SQLite3::Database.new "echoes_feeder.db"
end

def ensure_playlists_table!
  result = db.execute "SELECT name FROM sqlite_master WHERE type='table' AND name='playlists';"
  if result.empty?
    db.execute <<-SQL
      create table playlists (
        name varchar(30),
        created_at text,
        apple_id varchar(50)
      );
    SQL
  end
end
# POST https://api.music.apple.com/v1/me/library/playlist-folders

# res = AppleMusic::Client.post("me/library/playlist-folders", {
#   attributes: { name: "Echoes" }
# })
# binding.break
def create_apple_playlist(echoes_playlist, track_data)
  puts "\ncreating playlist on apple music..."

  name_parts = echoes_playlist.name.split(" – ")
  date = Date.parse(name_parts.first).to_s
  name = "#{date} #{name_parts.last}"

  res = AppleMusic::Client.post("me/library/playlists", {
    attributes: { name: name, description: ""},
    relationships: {
      tracks: { data: track_data },
      parent: { data: [{ id: ECHOES_FOLDER_ID, type: "library-playlist-folders" }] }
    }
  })

  if res.code == "201"
    apple_playlist_id = JSON.parse(res.body)["data"].first["id"]
    return unless apple_playlist_id
    db.execute "insert into playlists (name, created_at, apple_id) values ( ?, ?, ? )", [echoes_playlist.name, echoes_playlist.created_at.to_s, apple_playlist_id]
  else
    binding.break
  end

  apple_playlist_id
end

def search(term)
  params = { term: term, types: ["songs"], l: "en-us" }
  res = AppleMusic::Client.get("catalog/us/search", params)

  JSON.parse(res.body)["results"]["songs"]
end

def find_song(track, search_results)
  song = search_results["data"].find do |song|
    song["attributes"]["albumName"].downcase == track.album.downcase
  end
  song = search_results["data"].first if song.nil?
  song
end

# BEGIN APP CODE
# =======================================================
ensure_playlists_table!

playlist = EchoesFeed.most_recent_playlist
return if playlist.nil?

saved_apple_playlist_id = db.execute("select apple_id from playlists where created_at = ? and name = ?", [playlist.created_at.to_s, playlist.name]).first&.first

puts "PLAYLIST ALREADY IMPORTED!" if saved_apple_playlist_id
return unless saved_apple_playlist_id.nil?

playlist.tracks.each do |track|
  term = "#{track.artist} #{track.name}"
  params = { term: term, l: "en-us" };
  res = AppleMusic::Client.get("catalog/us/search/hints", params)

  if res.code == "200"
    term = JSON.parse(res.body)["results"]["terms"].first
    next if term.empty?

    # puts "found term #{term}"
    if term == "inbar bakal 04 song of songs"
      term = "inbar bakal song of songs"
    end
    search_results = search(term)
    if search_results.nil?
      if term.include?("(")
        term = term.split("(").first.chop
      elsif term.match(/\d+/)
        term.gsub!(/\d+/, "")
      else
        term = nil
      end
      if term
        # puts "-> try new term #{term}"
        search_results = search(term)
      end
    end
    next if search_results.nil?

    song = find_song(track, search_results)
    print "."

    track.apple_data = song if song
  else
    puts JSON.parse(res.body)
  end
end

track_data = playlist.tracks.each_with_object([]) do |t, results|
  results << { id: t.apple_data["id"], type: "songs" } if t.apple_data
end
return if track_data.empty?

apple_playlist_id = create_apple_playlist(playlist, track_data)
# res = AppleMusic::Client.post("me/library/playlists/#{apple_playlist_id}/tracks", { data: track_data })

if apple_playlist_id
  db.execute "update playlists set apple_id = ? where name = ? and created_at = ?", [apple_playlist_id, playlist.name, playlist.created_at.to_s]
  print "SUCCESS!!\n"
else
  print "PLAYLIST CREATION NOT SUCCESSFUL\n"
end
# puts
# If file doesn't exist
# `nohup ruby server.rb -e production >> log/server.log 2>&1 &`
# puts $?
# `open -a Safari localhost:4567/authorize`
