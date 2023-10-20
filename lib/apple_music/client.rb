# frozen_string_literal: true
require "net/https"
require 'dotenv/load'
require "jwt"

module AppleMusic
  class Client
    class ApiError < StandardError; end
    BASE_URL = "https://api.music.apple.com"

    def self.search(term, types: ["songs"])
      params = { term: term, types: types, l: "en-us" }
      res = get("/v1/catalog/us/search", params)

      res&.fetch("results")
    end

    def self.search_hints(term)
      params = { term: term, l: "en-us" };
      AppleMusic::Client.get("/v1/catalog/us/search/hints", params)
    end

    def self.create_playlist(parent_id, name, track_data = [])
      res = AppleMusic::Client.post("/v1/me/library/playlists", {
        attributes: {
          name: name,
          description: ""
        },
        relationships: {
          tracks: { data: track_data },
          parent: { data: [{ id: parent_id, type: "library-playlist-folders" }] }
        }
      })
      res["data"].first
    end

    def self.get(url, params = {})
      new.get(url, params)
    end

    def self.post(url, data = {})
      new.post(url, data)
    end

    def self.authentication_token
      new.authentication_token
    end

    def initialize
      @secret_key_path = "AuthKey_#{ENV["APPLE_MUSIC_KEY_ID"]}.p8"
      @team_id = ENV["APPLE_TEAM_ID"]
      @music_id = ENV["APPLE_MUSIC_KEY_ID"]
      @token_expire_at =  Time.now + (60 * 60 * 24)

      file = File.open("music_user_token.json", "r")
      @music_user_token = JSON.parse(file.read)["token"] if file.size > 0
    end

    def get(endpoint, params={})
      uri = URI("#{BASE_URL}#{endpoint}")
      uri.query = URI.encode_www_form(params) if params.any?

      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{authentication_token}"
      resp = http(uri).request(req)
      resp_body = JSON.parse(resp.body)
      if resp.code != "200"
        raise ApiError, resp_body.merge({endpoint: endpoint, params: params})
      end
      resp_body
    end

    # POST https://api.music.apple.com/v1/me/library/playlists
    # Apple::MusicClient.post("me/library/playlists", { name: "Testing", tracks: [], })
    def post(endpoint, data)
      uri = URI("#{BASE_URL}#{endpoint}")
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{authentication_token}"
      req["music-user-token"] = @music_user_token
      req.content_type = 'application/json'
      req.body = data.to_json.to_s

      resp = http(uri).request(req)
      resp_body = JSON.parse(resp.body)
      if resp.code != "201"
        raise ApiError, resp_body
      end
      resp_body
    end

    def authentication_token
      private_key = OpenSSL::PKey::EC.new(apple_music_secret_key)
      JWT.encode authentication_payload, private_key, 'ES256', kid: @music_id
    end

    private

    def authentication_payload
      {
        iss: @team_id,
        iat: Time.now.to_i,
        exp: @token_expire_at.to_i
      }
    end

    def apple_music_secret_key
      @apple_music_secret_key ||= File.read(@secret_key_path)
    end

    def http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http
    end
  end
end
