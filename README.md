# Echoes Feeder

My favorite ambient radio show is [Echoes](https://echoes.org). They don't create playlists on Apple Music, my primary place to listen to music, but they publish their playlists in an RSS feed. This code fetches the feed, looks for the tracks on Apple Music, creates the playlist on my Apple Music account and tracks what has been successfully created.

## Requirements
 * Apple Developer Account to generate api key
 * Apple Music account to add the playlist to

## Authentication

Create a `.env` file and add the necessary authentication variables.

 * APPLE_TEAM_ID - This is the Team ID listed in the Apple Developer Membership Details.
 * APPLE_MUSIC_KEY_ID - [Generate an Apple Developer Key that can access MusicKit](https://developer.apple.com/help/account/configure-app-capabilities/create-a-media-identifier-and-private-key/). Download the key and add to the root of this project. The gitignore is configured to ignore `.p8` files but just incase, ensure it's not checked into the git repo. Set this value to  the Key ID set by Apple and shown in their UI once the key is generated.

Run the server and go to `localhost:4567/authorize` and follow the Apple Authorization popup tto generate a music user token which will be save to `music_user_token.json`:

```ruby
ruby server.rb
```

## Running the Script

Run the script to import a playlist from the feed:

```ruby
ruby app.rb
```

## Running the Script in the background

Adding the script to the Mac crontab:

```bash
EDITOR=vi crontab -e
```

Add the following to have it run daily at noon:
```cron
0 12 * * * cd <location of echoes_feeder folder> && ruby app.rb
```
