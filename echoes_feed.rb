# frozen_string_literal: true
require "rss"
require "nokogiri"
require "ostruct"

class Track
  attr_reader :artist, :name, :album
  def initialize(artist:, name:, album:)
    @artist = artist
    @name = name
    @album = album
  end

  def to_json(options = {})
    { artist: artist, name: name, album: album }.to_json(options)
  end
end

class EchoesFeed
  URL = "https://echoes.org/category/playlists/feed"
  TRACK_TIMESTAMP_PATTERN = /\d\:\d{2}\:\d{2}/
  BREAK_ROW_PATTERN = /break/

  def self.get_most_recent_playlist_data
    new.get_most_recent_playlist_data
  end

  def get_most_recent_playlist_data
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

  def most_recent_playlist_rows
    content = Nokogiri::HTML(most_recent_feed_item.content_encoded)
    content.css("tr").select do |row|
      cells = row.css("td")
      cells.length == 4 &&
        cells.first.text.match(TRACK_TIMESTAMP_PATTERN) &&
        !cells[1].text.match(BREAK_ROW_PATTERN)
    end
  end
end
