class EchoesFeed
  class Playlist
    attr_reader :name, :tracks, :created_at
    attr_accessor :has_track_data

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
          name: cells[2].text.gsub("(Live on Echoes)", ""),
          album: cells[3].text
        )
      end
      new(name: name, tracks: tracks, created_at: created_at)
    end

    def has_track_data?
      !!has_track_data
    end
  end
end
