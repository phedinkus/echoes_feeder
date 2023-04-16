# frozen_string_literal: true
require "net/https"
require 'dotenv/load'
require "jwt"

module Apple
  class MusicClient
    BASE_URL = "https://api.music.apple.com/v1/"

    def self.get(url, params = {})
      new.get(url, params)
    end

    def initialize
      @secret_key_path = "AuthKey_#{ENV["APPLE_MUSIC_KEY_ID"]}.p8"
      @team_id = ENV["APPLE_TEAM_ID"]
      @music_id = ENV["APPLE_MUSIC_KEY_ID"]
      @token_expire_at =  Time.now + (60 * 60 * 24)
    end

    def get(endpoint, params={})
      uri = URI("#{BASE_URL}#{endpoint}")
      uri.query = URI.encode_www_form(params) if params.any?

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{authentication_token}"
      http.request(req)
    end

    private

    def authentication_payload
      {
        iss: @team_id,
        iat: Time.now.to_i,
        exp: @token_expire_at.to_i
      }
    end

    def authentication_token
      private_key = OpenSSL::PKey::EC.new(apple_music_secret_key)
      JWT.encode authentication_payload, private_key, 'ES256', kid: @music_id
    end

    def apple_music_secret_key
      @apple_music_secret_key ||= File.read(@secret_key_path)
    end
  end
end
