class EchoesFeed
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
end
