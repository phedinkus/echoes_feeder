# frozen_string_literal: true
require "rss"
require "nokogiri"
require "ostruct"
require_relative "./echoes_feed/playlist"
require_relative "./echoes_feed/track"

class EchoesFeed
  URL = "https://echoes.org/category/playlists/feed"
  TRACK_TIMESTAMP_PATTERN = /\d\:\d{2}\:\d{2}/
  BREAK_ROW_PATTERN = /break/

  def self.most_recent_playlist
    new.most_recent_playlist
  end

  def playlists
    feed.items.map do |item|
      playlist_from_item(item)
    end
  end

  def most_recent_playlist
    playlist_from_item(most_recent_feed_item)
  end

  private

  def feed
    @feed ||= URI.open(URL) do |rss|
      RSS::Parser.parse(rss, false)
    end
  end

  def playlist_from_item(item)
    content = Nokogiri::HTML(item.content_encoded)
    rows = content.css("tr").select do |row|
      cells = row.css("td")
      cells.length == 4 &&
      cells.first.text.match(TRACK_TIMESTAMP_PATTERN) &&
      !cells[1].text.match(BREAK_ROW_PATTERN)
    end
    Playlist.create_from_feed(name: item.title,  raw_track_data: rows, created_at: item.pubDate)
  end

  def most_recent_feed_item
    @feed_item ||= feed.items.first
  end
end
