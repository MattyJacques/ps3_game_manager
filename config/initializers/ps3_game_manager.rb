Rails.application.configure do
  config.x.nas_path = ENV.fetch("NAS_PATH", "/nas")
  config.x.gametdb_archive_url = ENV.fetch("GAMETDB_ARCHIVE_URL", "https://www.gametdb.com/ps3tdb.zip")
  config.x.gametdb_refresh_hours = ENV.fetch("GAMETDB_REFRESH_HOURS", "24").to_i
  config.x.gametdb_cache_dir = Rails.root.join("storage", "gametdb")
  config.x.cover_cache_dir = Rails.root.join("storage", "covers")
end
