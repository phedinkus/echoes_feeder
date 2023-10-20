require "sqlite3"
require "active_record"

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'echoes_feeder_development.db'
)
unless ActiveRecord::Base.connection.table_exists?(:imported_playlists)
  ActiveRecord::Migration.create_table :imported_playlists do |table|
    table.string :name
    table.string :apple_id
    table.datetime :echoes_created_at
    table.timestamps
  end
end
