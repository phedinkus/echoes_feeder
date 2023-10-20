class EchoesFeed
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
end
