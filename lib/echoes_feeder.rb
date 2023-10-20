require "./config/initialize"
require_relative "./echoes_feed"
require_relative "./apple"
require_relative "./models/imported_playlist"

class EchoesFeeder
  APPLE_ECHOES_FOLDER_ID = "p.3VKWEkDuMeRRR"

  def import_most_recent_playlist!
    playlist = EchoesFeed.most_recent_playlist
    return if playlist.nil?

    saved_playlist = ImportedPlaylist.find_by(echoes_created_at: playlist.created_at.to_date)
    if saved_playlist.present?
      puts "PLAYLIST ALREADY IMPORTED!"
      return
    end

    enhance_tracks_with_apple_data!(playlist)
    apple_playlist = create_apple_playlist!(playlist)

    ImportedPlaylist.create!(
      name: apple_playlist["name"],
      apple_id: apple_playlist["id"],
      echoes_created_at: playlist.created_at.to_date
    )
    puts "SUCCESS!"
  end

  private

  def enhance_tracks_with_apple_data!(playlist)
    playlist.tracks.each do |track|
      term = "#{track.artist} #{track.name}"
      search_hint = AppleMusic::Client.search_hints(term)["results"]["terms"].first
      if search_hint.empty?
        print "."
        next
      end

      # puts "found term #{search_hint}"
      search_results = AppleMusic::Client.search(search_hint)
      if search_results.nil?
        print "?"
        if search_hint.include?("(")
          search_hint = search_hint.split("(").first.chop
        elsif search_hint.match(/\d+/)
          search_hint.gsub!(/\d+/, "")
        else
          search_hint = nil
        end

        if search_hint
          # puts "-> try new search_hint #{search_hint}"
          search_results = AppleMusic::Client.search(search_hint)
        end
      end
      next if search_results.nil?

      song = search_results["data"].find do |song|
        song["attributes"]["albumName"].downcase == track.album.downcase
      end
      song = search_results["data"].first if song.nil?

      track.apple_data = song if song
      print "+"
    end
  end

  def create_apple_playlist!(playlist)
    track_data = playlist.tracks.each_with_object([]) do |t, results|
      results << { id: t.apple_data["id"], type: "songs" } if t.apple_data
    end
    return if track_data.empty?

    name_parts = playlist.name.split(" – ")
    name = "#{playlist.created_at.to_date.to_s} #{name_parts.last}"

    puts "creating Apple playlist..."
    AppleMusic::Client.create_playlist(APPLE_ECHOES_FOLDER_ID, name, "", track_data)
  end
end
