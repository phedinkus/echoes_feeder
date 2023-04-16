require 'rss'
require 'open-uri'
require 'nokogiri'
require 'ostruct'

require 'debug'

url = 'https://echoes.org/category/playlists/feed'
URI.open(url) do |rss|
  feed = RSS::Parser.parse(rss, false)
  puts "Title: #{feed.channel.title}"
  feed_item = feed.items.first
  content = Nokogiri::HTML(feed_item.content_encoded)
  rows = content.css("tr").select do |row|
    cells = row.css("td")
    cells.length == 4 &&
      cells.first.text.match(/\d\:\d{2}\:\d{2}/) &&
      !cells[1].text.match(/break/)
  end
  track_data = rows.map do |row|
    cells = row.css("td")
    OpenStruct.new(
      artist: cells[1].text,
      song_name: cells[2].text,
      album_name: cells[3].text
    )
  end
  binding.break
  1
end
