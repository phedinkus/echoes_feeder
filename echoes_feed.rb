# frozen_string_literal: true
require "rss"
require "nokogiri"
require "ostruct"

class Track
  attr_reader :artist, :name, :album
  attr_accessor :apple_data
  def initialize(artist:, name:, album:)
    @artist = artist
    @name = name
    @album = album
  end

  def to_json(options = {})
    { artist: artist, name: name, album: album }.to_json(options)
  end
end

class Playlist
  attr_reader :name, :tracks, :created_at

  def initialize(name:, tracks: [], created_at:)
    @name = name
    @tracks = tracks
    @created_at = created_at
  end

  def self.create_from_feed(name:, raw_track_data:, created_at:)
    tracks = raw_track_data.map do |row|
      cells = row.css("td")
      Track.new(
        artist: cells[1].text,
        name: cells[2].text,
        album: cells[3].text
      )
    end
    new(name: name, tracks: tracks, created_at: created_at)
  end
end

class EchoesFeed
  URL = "https://echoes.org/category/playlists/feed"
  TRACK_TIMESTAMP_PATTERN = /\d\:\d{2}\:\d{2}/
  BREAK_ROW_PATTERN = /break/

  def self.most_recent_playlist
    new.most_recent_playlist
  end

  def get_most_recent_playlist_tracks
    most_recent_playlist_rows.map do |row|
      cells = row.css("td")
      Track.new(
        artist: cells[1].text,
        name: cells[2].text,
        album: cells[3].text
      )
    end
  end

  def feed
    @feed ||= URI.open(URL) do |rss|
      RSS::Parser.parse(rss, false)
    end
  end

  def most_recent_feed_item
    @feed_item ||= feed.items.first
  end

  def most_recent_playlist
    content = Nokogiri::HTML(most_recent_feed_item.content_encoded)
    rows = content.css("tr").select do |row|
      cells = row.css("td")
      cells.length == 4 &&
      cells.first.text.match(TRACK_TIMESTAMP_PATTERN) &&
      !cells[1].text.match(BREAK_ROW_PATTERN)
    end
    Playlist.create_from_feed(name: most_recent_feed_item.title,  raw_track_data: rows, created_at: most_recent_feed_item.pubDate)
  end
end
