require "./config/initialize"
require_relative "./echoes_feed"
require_relative "./apple"
require_relative "./models/imported_playlist"
require "debug"

class EchoesFeeder
  class TrackDataMissing < StandardError; end
  APPLE_ECHOES_FOLDER_ID = "p.3VKWEkDuMeRRR"

  def import_most_recent_playlist!
    playlist = EchoesFeed.most_recent_playlist
    return if playlist.nil?
    import_playlist!(playlist)
  end

  def import_playlist!(playlist)
    saved_playlist = ImportedPlaylist.find_by(echoes_created_at: playlist.created_at.to_date)
    if saved_playlist.present?
      if saved_playlist.name.nil?
        saved_playlist.update!(name: playlist_name(playlist))
      end
      puts "PLAYLIST ALREADY IMPORTED!"
      return
    end

    enhance_tracks_with_apple_data!(playlist)

    return unless playlist.has_track_data?

    apple_playlist = create_apple_playlist!(playlist)

    if apple_playlist
      ip = ImportedPlaylist.create!(
        name: apple_playlist["attributes"]["name"],
        apple_id: apple_playlist["id"],
        echoes_created_at: playlist.created_at.to_date
      )
      puts "SUCCESS!"
      notification_command = <<-BASH
        X="Created Echoes Playlist: #{ip.name}" /usr/bin/osascript -e 'display notification system attribute "X"'
      BASH
      system(notification_command)
    else
      puts "IMPORT FAILED!"
      false
    end
  end

  private

  def playlist_name(playlist)
    name_parts = playlist.name.split(" – ")
    "#{playlist.created_at.to_date.to_s} #{name_parts.last}"
  end

  def enhance_tracks_with_apple_data!(playlist)
    playlist.tracks.each do |track|
      song_data = apple_data_for_track(track)

      if song_data
        track.apple_data = song_data
        print "+"
        playlist.has_track_data = true
      end
    end
  end

  def apple_data_for_track(track)
    # start by looking for the track by name
    song = search_track_name(track)
    return song if song.present?

    # search by album name
    song = search_by_album(track)
    return song if song.present?

    search_with_hints(track)
  end

  def create_apple_playlist!(playlist)
    track_data = playlist.tracks.each_with_object([]) do |t, results|
      results << { id: t.apple_data["id"], type: "songs" } if t.apple_data
    end
    raise TrackDataMissing if track_data.empty?

    name = playlist_name(playlist)

    puts "creating Apple playlist..."
    AppleMusic::Client.create_playlist(APPLE_ECHOES_FOLDER_ID, name, track_data)
  end

  def search_track_name(track)
    search_results = AppleMusic::Client.search(track.name)
    unless search_results.empty?
      search_results["songs"]["data"].find do |s|
        s["attributes"]["albumName"].downcase == track.album.downcase || s["attributes"]["artistName"].downcase == track.artist.downcase
      end
    end
  end

  def search_by_album(track)
    return unless track.album.present?

    search_results = AppleMusic::Client.search(track.album, types: ["albums"])
    unless search_results.empty?
      album = search_results["albums"]["data"].find do |a|
        a["attributes"]["name"].downcase == track.album.downcase || a["attributes"]["artistName"].downcase == track.artist.downcase
      end
      if album
        album_result = AppleMusic::Client.get(album["href"])["data"].first
        unless album_result.empty?
          album_result["relationships"]["tracks"]["data"].find do |s|
            s["attributes"]["albumName"].downcase == track.album.downcase || s["attributes"]["artistName"].downcase == track.artist.downcase
          end
        end
      end
    end
  end

  def search_with_hints(track)
    # search with Apple's search hints
    search_term = "#{track.artist} #{track.name}"
    search_results = AppleMusic::Client.search(search_term)
    if search_results.empty?
      search_hint = AppleMusic::Client.search_hints(search_term)["results"]["terms"].first
      if search_hint.empty?
        print "."
        return
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
    end

    if search_results.empty?
      puts "No songs found for #{search_term}"
      return
    end

    song = search_results["songs"]["data"].find do |song|
      song["attributes"]["albumName"].downcase == track.album.downcase
    end
    song = search_results["songs"]["data"].first if song.nil?
    song
  end
end
