# PS3 Game Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Rails 8 web app that scans a read-only NAS mount for PS3 `.iso` and `.pkg` files, enriches them from GameTDB, and exposes owned, missing, unidentified, and wishlist views.

**Architecture:** Generate a fresh Rails 8 app in the existing repository root, keep PS3-specific logic in small service objects under `app/services`, and use server-rendered Hotwire pages for the UI. Persist the catalog in SQLite, run manual scans through Solid Queue in the same container, and cache GameTDB data and cover art on disk under the app's persistent storage volume.

**Tech Stack:** Ruby 3.3, Rails 8, SQLite, Solid Queue, Hotwire/Turbo, Tailwind, Minitest, Nokogiri, rubyzip, Docker Compose

---

## File Structure

- `Gemfile`: add `nokogiri` for GameTDB XML parsing and `rubyzip` for archive extraction.
- `config/routes.rb`: define dashboard, scan trigger, library, missing, unidentified, and wishlist routes.
- `config/initializers/ps3_game_manager.rb`: centralize `NAS_PATH`, GameTDB URLs, refresh interval, and cache directories.
- `db/migrate/20260617000100_create_games.rb`: canonical game catalog.
- `db/migrate/20260617000200_create_media_files.rb`: one row per NAS file.
- `db/migrate/20260617000300_create_wishlist_items.rb`: wanted titles ordered by priority.
- `db/migrate/20260617000400_create_scans.rb`: scan run summaries.
- `app/models/game.rb`: associations, validations, `owned` scope, catalog upsert helper.
- `app/models/media_file.rb`: scopes for present, missing, unidentified files.
- `app/models/wishlist_item.rb`: ordering and `owned?` helper.
- `app/models/scan.rb`: status enum and summary helpers.
- `app/services/title_id/extractor.rb`: strategy chain entry point.
- `app/services/title_id/pkg_header.rb`: PKG `content_id` parsing.
- `app/services/title_id/iso_image.rb`: ISO9660 lookup for `PS3_GAME/PARAM.SFO`.
- `app/services/title_id/param_sfo.rb`: `PARAM.SFO` parser for `TITLE_ID` and `TITLE`.
- `app/services/game_tdb/sync.rb`: download and refresh the cached GameTDB archive.
- `app/services/game_tdb/catalog.rb`: lookup and search against the cached XML.
- `app/services/game_tdb/cover_cache.rb`: fetch and cache cover art on demand.
- `app/services/library/scanner.rb`: walk the NAS, upsert files, mark missing files, and enrich metadata.
- `app/jobs/scan_job.rb`: background scan execution and Turbo progress broadcasts.
- `app/controllers/dashboard_controller.rb`: landing page with summary cards and scan status.
- `app/controllers/scans_controller.rb`: enqueue manual scans.
- `app/controllers/library_controller.rb`: owned game browsing and filters.
- `app/controllers/covers_controller.rb`: serve cached cover files from persistent storage.
- `app/controllers/missing_media_files_controller.rb`: files no longer present on the NAS.
- `app/controllers/unidentified_media_files_controller.rb`: unidentified files list.
- `app/controllers/media_file_identifications_controller.rb`: manual title ID entry.
- `app/controllers/wishlist_items_controller.rb`: wishlist listing and CRUD.
- `app/controllers/wishlist_searches_controller.rb`: Turbo-backed GameTDB search.
- `app/views/dashboard/index.html.erb`: dashboard shell.
- `app/views/scans/_scan_status.html.erb`: shared progress/status partial.
- `app/views/library/index.html.erb`: owned games grid and filters.
- `app/views/missing_media_files/index.html.erb`: missing files table.
- `app/views/unidentified_media_files/index.html.erb`: unidentified files and manual fix forms.
- `app/views/wishlist_items/index.html.erb`: wishlist list and add flow.
- `app/views/wishlist_searches/_results.html.erb`: Turbo search results.
- `test/models/*.rb`: model behavior.
- `test/services/**/*.rb`: scanner, metadata, and title parsing behavior.
- `test/jobs/scan_job_test.rb`: background flow and progress broadcasts.
- `test/controllers/covers_controller_test.rb`: cached cover delivery.
- `test/system/*.rb`: dashboard, library, and wishlist user flows.
- `Dockerfile`, `docker-compose.yml`, `.dockerignore`, `bin/docker-entrypoint`, `README.md`: Raspberry Pi deployment.

### Task 1: Scaffold the Rails app and dashboard shell

**Files:**
- Create: standard Rails 8 app files under `app/`, `bin/`, `config/`, `db/`, `test/`
- Create: `config/initializers/ps3_game_manager.rb`
- Create: `app/controllers/dashboard_controller.rb`
- Create: `app/views/dashboard/index.html.erb`
- Modify: `config/routes.rb`
- Test: `test/controllers/dashboard_controller_test.rb`

- [ ] **Step 1: Generate the Rails application in place**

```bash
rails new . --force --database=sqlite3 --css=tailwind
bundle install
```

Expected: Rails creates the application skeleton in the repository root without deleting `docs/`.

- [ ] **Step 2: Add a failing dashboard smoke test**

```ruby
# test/controllers/dashboard_controller_test.rb
require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows the dashboard shell" do
    get root_url

    assert_response :success
    assert_select "h1", "PS3 Game Manager"
    assert_select "button", "Scan now"
    assert_select "a", "Library"
    assert_select "a", "Wishlist"
  end
end
```

- [ ] **Step 3: Run the new smoke test to verify it fails**

Run: `bin/rails test test/controllers/dashboard_controller_test.rb`

Expected: FAIL with a routing or missing controller error because the app does not yet expose a dashboard.

- [ ] **Step 4: Add app configuration, the root route, and a minimal dashboard page**

```ruby
# config/initializers/ps3_game_manager.rb
Rails.application.configure do
  config.x.nas_path = ENV.fetch("NAS_PATH", "/nas")
  config.x.gametdb_archive_url = ENV.fetch("GAMETDB_ARCHIVE_URL", "https://www.gametdb.com/ps3tdb.zip")
  config.x.gametdb_refresh_hours = ENV.fetch("GAMETDB_REFRESH_HOURS", "24").to_i
  config.x.gametdb_cache_dir = Rails.root.join("storage", "gametdb")
  config.x.cover_cache_dir = Rails.root.join("storage", "covers")
end
```

```ruby
# config/routes.rb
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"
end
```

```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index; end
end
```

```erb
<!-- app/views/dashboard/index.html.erb -->
<div class="mx-auto flex max-w-5xl flex-col gap-6 px-4 py-8">
  <header class="flex items-center justify-between">
    <div>
      <h1 class="text-3xl font-bold">PS3 Game Manager</h1>
      <p class="text-slate-600">Track owned games, missing files, and wishlist matches from one NAS scan.</p>
    </div>
    <button class="rounded bg-slate-900 px-4 py-2 text-white" type="button">Scan now</button>
  </header>

  <nav class="flex gap-4 text-sm font-medium text-slate-700">
    <a href="#">Library</a>
    <a href="#">Wishlist</a>
    <a href="#">Missing</a>
    <a href="#">Unidentified</a>
  </nav>
</div>
```

- [ ] **Step 5: Run the dashboard smoke test again**

Run: `bin/rails test test/controllers/dashboard_controller_test.rb`

Expected: PASS

- [ ] **Step 6: Commit the scaffold and dashboard shell**

```bash
git add .
git commit -m "feat: bootstrap rails app for PS3 catalog"
```

### Task 2: Create the catalog schema and model behavior

**Files:**
- Create: `db/migrate/20260617000100_create_games.rb`
- Create: `db/migrate/20260617000200_create_media_files.rb`
- Create: `db/migrate/20260617000300_create_wishlist_items.rb`
- Create: `db/migrate/20260617000400_create_scans.rb`
- Modify: `app/models/game.rb`
- Modify: `app/models/media_file.rb`
- Modify: `app/models/wishlist_item.rb`
- Modify: `app/models/scan.rb`
- Test: `test/models/game_test.rb`
- Test: `test/models/media_file_test.rb`
- Test: `test/models/wishlist_item_test.rb`

- [ ] **Step 1: Write the failing model tests**

```ruby
# test/models/game_test.rb
require "test_helper"

class GameTest < ActiveSupport::TestCase
  test "owned scope only returns games with present media files" do
    owned = Game.create!(title_id: "BLUS30490", name: "Wanted", region: "US", kind: "disc")
    missing = Game.create!(title_id: "BLES00682", name: "Missing", region: "EU", kind: "disc")

    MediaFile.create!(path: "/nas/Wanted.iso", file_format: "iso", byte_size: 1, title_id: owned.title_id, game: owned, present: true, first_seen_at: Time.current, last_seen_at: Time.current)
    MediaFile.create!(path: "/nas/Missing.iso", file_format: "iso", byte_size: 1, title_id: missing.title_id, game: missing, present: false, first_seen_at: Time.current, last_seen_at: Time.current)

    assert_equal [owned], Game.owned.order(:title_id).to_a
  end
end
```

```ruby
# test/models/media_file_test.rb
require "test_helper"

class MediaFileTest < ActiveSupport::TestCase
  test "unidentified scope returns files without a title id" do
    unidentified = MediaFile.create!(path: "/nas/Unknown.iso", file_format: "iso", byte_size: 1, present: true, first_seen_at: Time.current, last_seen_at: Time.current)
    identified = MediaFile.create!(path: "/nas/Known.iso", file_format: "iso", byte_size: 1, title_id: "BLUS30490", present: true, first_seen_at: Time.current, last_seen_at: Time.current)

    assert_includes MediaFile.unidentified, unidentified
    assert_not_includes MediaFile.unidentified, identified
  end
end
```

```ruby
# test/models/wishlist_item_test.rb
require "test_helper"

class WishlistItemTest < ActiveSupport::TestCase
  test "owned? returns true when the game has a present media file" do
    game = Game.create!(title_id: "BLUS30490", name: "Wanted", region: "US", kind: "disc")
    wishlist_item = WishlistItem.create!(game: game, notes: "keep an eye out", priority: 3)

    MediaFile.create!(path: "/nas/Wanted.iso", file_format: "iso", byte_size: 1, title_id: game.title_id, game: game, present: true, first_seen_at: Time.current, last_seen_at: Time.current)

    assert wishlist_item.owned?
  end
end
```

- [ ] **Step 2: Run the model tests to verify they fail**

Run: `bin/rails test test/models/game_test.rb test/models/media_file_test.rb test/models/wishlist_item_test.rb`

Expected: FAIL with missing tables and undefined model behavior.

- [ ] **Step 3: Add the four domain migrations**

```ruby
# db/migrate/20260617000100_create_games.rb
class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.string :title_id, null: false
      t.string :name, null: false
      t.string :region, null: false
      t.string :kind, null: false
      t.string :cover_path

      t.timestamps
    end

    add_index :games, :title_id, unique: true
    add_index :games, :name
  end
end
```

```ruby
# db/migrate/20260617000200_create_media_files.rb
class CreateMediaFiles < ActiveRecord::Migration[8.0]
  def change
    create_table :media_files do |t|
      t.string :path, null: false
      t.string :file_format, null: false
      t.bigint :byte_size, null: false
      t.string :title_id
      t.references :game, foreign_key: true
      t.boolean :present, null: false, default: true
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false

      t.timestamps
    end

    add_index :media_files, :path, unique: true
    add_index :media_files, :title_id
    add_index :media_files, :present
  end
end
```

```ruby
# db/migrate/20260617000300_create_wishlist_items.rb
class CreateWishlistItems < ActiveRecord::Migration[8.0]
  def change
    create_table :wishlist_items do |t|
      t.references :game, null: false, foreign_key: true
      t.text :notes, null: false, default: ""
      t.integer :priority, null: false, default: 0

      t.timestamps
    end

    add_index :wishlist_items, [:game_id], unique: true
    add_index :wishlist_items, :priority
  end
end
```

```ruby
# db/migrate/20260617000400_create_scans.rb
class CreateScans < ActiveRecord::Migration[8.0]
  def change
    create_table :scans do |t|
      t.string :status, null: false, default: "running"
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :files_found, null: false, default: 0
      t.integer :errors_count, null: false, default: 0
      t.string :summary, null: false, default: ""

      t.timestamps
    end

    add_index :scans, :status
    add_index :scans, :started_at
  end
end
```

- [ ] **Step 4: Implement the model behavior**

```ruby
# app/models/game.rb
class Game < ApplicationRecord
  has_many :media_files, dependent: :nullify
  has_many :wishlist_items, dependent: :destroy

  validates :title_id, :name, :region, :kind, presence: true
  validates :title_id, uniqueness: true
  validates :kind, inclusion: { in: %w[disc psn] }

  scope :owned, -> { joins(:media_files).merge(MediaFile.present_now).distinct }

  def self.upsert_from_catalog!(title_id:, entry:)
    game = find_or_initialize_by(title_id: title_id)
    game.name = entry.fetch(:name)
    game.region = entry.fetch(:region)
    game.kind = entry.fetch(:kind)
    game.save!
    game
  end
end
```

```ruby
# app/models/media_file.rb
class MediaFile < ApplicationRecord
  belongs_to :game, optional: true

  validates :path, :file_format, :byte_size, :first_seen_at, :last_seen_at, presence: true
  validates :path, uniqueness: true
  validates :file_format, inclusion: { in: %w[iso pkg] }

  scope :present_now, -> { where(present: true) }
  scope :missing, -> { where(present: false) }
  scope :unidentified, -> { present_now.where(title_id: nil) }
end
```

```ruby
# app/models/wishlist_item.rb
class WishlistItem < ApplicationRecord
  belongs_to :game

  validates :priority, numericality: { only_integer: true }

  scope :ordered, -> { order(priority: :desc, created_at: :asc) }

  def owned?
    game.media_files.present_now.exists?
  end
end
```

```ruby
# app/models/scan.rb
class Scan < ApplicationRecord
  validates :status, :started_at, :summary, presence: true
  validates :status, inclusion: { in: %w[running completed failed] }

  scope :recent_first, -> { order(started_at: :desc) }

  def complete!(files_found:, errors_count:, summary:)
    update!(
      status: "completed",
      finished_at: Time.current,
      files_found: files_found,
      errors_count: errors_count,
      summary: summary
    )
  end

  def fail!(summary:)
    update!(status: "failed", finished_at: Time.current, summary: summary)
  end
end
```

- [ ] **Step 5: Run migrations and rerun the model tests**

Run: `bin/rails db:migrate && bin/rails test test/models/game_test.rb test/models/media_file_test.rb test/models/wishlist_item_test.rb`

Expected: PASS

- [ ] **Step 6: Commit the schema and models**

```bash
git add db/migrate app/models test/models
git commit -m "feat: add catalog schema and model queries"
```

### Task 3: Implement filename and PKG title ID extraction

**Files:**
- Create: `app/services/title_id/extractor.rb`
- Create: `app/services/title_id/pkg_header.rb`
- Test: `test/services/title_id/extractor_test.rb`

- [ ] **Step 1: Write the failing extractor tests**

```ruby
# test/services/title_id/extractor_test.rb
require "test_helper"

class TitleIdExtractorTest < ActiveSupport::TestCase
  test "extracts the title id from the filename" do
    extractor = TitleId::Extractor.new

    assert_equal "BLUS30490", extractor.call("/nas/Action/BLUS30490-God of War III.iso")
  end

  test "extracts the title id from the parent folder when the filename is generic" do
    extractor = TitleId::Extractor.new

    assert_equal "BLES00682", extractor.call("/nas/BLES00682/Game Backup.iso")
  end

  test "falls back to the PKG header content id" do
    Dir.mktmpdir do |dir|
      pkg_path = File.join(dir, "mystery.pkg")
      File.binwrite(pkg_path, "\x00" * 32 + "EP9000-BLES00682_00-GAME00000000001" + "\x00" * 32)

      extractor = TitleId::Extractor.new
      assert_equal "BLES00682", extractor.call(pkg_path)
    end
  end
end
```

- [ ] **Step 2: Run the extractor tests to verify they fail**

Run: `bin/rails test test/services/title_id/extractor_test.rb`

Expected: FAIL with `uninitialized constant TitleId`.

- [ ] **Step 3: Implement the regex strategy and PKG fallback**

```ruby
# app/services/title_id/extractor.rb
module TitleId
  class Extractor
    SERIAL_REGEX = /([A-Z]{4}\d{5})/

    def initialize(pkg_header: PkgHeader.new)
      @pkg_header = pkg_header
    end

    def call(path)
      filename_match(path) || pkg_match(path)
    end

    private

    attr_reader :pkg_header

    def filename_match(path)
      [File.basename(path), File.basename(File.dirname(path))].each do |candidate|
        match = candidate.match(SERIAL_REGEX)
        return match[1] if match
      end

      nil
    end

    def pkg_match(path)
      return unless File.extname(path).casecmp(".pkg").zero?

      pkg_header.call(path)
    end
  end
end
```

```ruby
# app/services/title_id/pkg_header.rb
module TitleId
  class PkgHeader
    CONTENT_ID_REGEX = /[A-Z]{2}\d{4}-([A-Z]{4}\d{5})_/

    def call(path)
      bytes = File.binread(path, 512)
      match = bytes.match(CONTENT_ID_REGEX)
      match && match[1]
    end
  end
end
```

- [ ] **Step 4: Run the extractor tests again**

Run: `bin/rails test test/services/title_id/extractor_test.rb`

Expected: PASS

- [ ] **Step 5: Commit the initial title ID extraction**

```bash
git add app/services/title_id test/services/title_id
git commit -m "feat: detect PS3 title ids from names and pkg headers"
```

### Task 4: Implement the ISO `PARAM.SFO` fallback

**Files:**
- Create: `app/services/title_id/iso_image.rb`
- Create: `app/services/title_id/param_sfo.rb`
- Modify: `app/services/title_id/extractor.rb`
- Test: `test/services/title_id/iso_image_test.rb`

- [ ] **Step 1: Write the failing ISO and SFO parser tests**

```ruby
# test/services/title_id/iso_image_test.rb
require "test_helper"

class TitleIdIsoImageTest < ActiveSupport::TestCase
  test "reads TITLE_ID from PARAM.SFO inside an ISO" do
    Dir.mktmpdir do |dir|
      iso_path = File.join(dir, "generic.iso")
      File.binwrite(iso_path, build_test_iso(build_param_sfo("TITLE_ID" => "BLUS30490", "TITLE" => "God of War III")))

      extractor = TitleId::Extractor.new
      assert_equal "BLUS30490", extractor.call(iso_path)
    end
  end

  private

  def build_param_sfo(values)
    keys = +""
    data = +""
    entries = values.map do |key, value|
      key_offset = keys.bytesize
      data_offset = data.bytesize

      keys << key << "\x00"
      data << value << "\x00"

      [key_offset, 0x0204, value.bytesize + 1, value.bytesize + 1, data_offset].pack("vvVVV")
    end.join

    key_table_start = 20 + entries.bytesize
    data_table_start = key_table_start + keys.bytesize

    ["\x00PSF", [0x00000101, key_table_start, data_table_start, values.size].pack("VVVV"), entries, keys, data].join
  end

  def build_test_iso(param_sfo_bytes)
    sectors = Array.new(24) { "\x00" * 2048 }
    primary_volume = "\x00" * 2048
    primary_volume.setbyte(0, 1)
    primary_volume[1, 5] = "CD001"
    primary_volume.setbyte(6, 1)
    primary_volume[156, 34] = directory_record(20, 2048, "\x00")
    sectors[16] = primary_volume

    root_directory = +""
    root_directory << directory_record(20, 2048, "\x00")
    root_directory << directory_record(20, 2048, "\x01")
    root_directory << directory_record(21, 2048, "PS3_GAME")
    sectors[20] = root_directory.ljust(2048, "\x00")

    ps3_directory = +""
    ps3_directory << directory_record(21, 2048, "\x00")
    ps3_directory << directory_record(20, 2048, "\x01")
    ps3_directory << directory_record(22, param_sfo_bytes.bytesize, "PARAM.SFO;1")
    sectors[21] = ps3_directory.ljust(2048, "\x00")

    sectors[22] = param_sfo_bytes.ljust(2048, "\x00")
    sectors.join
  end

  def directory_record(extent, size, name)
    name_bytes = name.b
    length = 33 + name_bytes.bytesize
    record = [length, 0, extent, extent, size, size].pack("CCVVVV")
    record << ("\x00" * 7)
    record << [0, 0, 1].pack("vCC")
    record << [name_bytes.bytesize].pack("C")
    record << name_bytes
    record << "\x00" if record.bytesize.odd?
    record.ljust(length + (length.odd? ? 1 : 0), "\x00")
  end
end
```

- [ ] **Step 2: Run the ISO test to verify it fails**

Run: `bin/rails test test/services/title_id/iso_image_test.rb`

Expected: FAIL because the extractor does not yet inspect ISOs.

- [ ] **Step 3: Implement `PARAM.SFO` parsing and ISO directory traversal**

```ruby
# app/services/title_id/param_sfo.rb
module TitleId
  class ParamSfo
    def call(bytes)
      raise ArgumentError, "invalid PARAM.SFO header" unless bytes.start_with?("\x00PSF")

      key_table_start = bytes[8, 4].unpack1("V")
      data_table_start = bytes[12, 4].unpack1("V")
      entry_count = bytes[16, 4].unpack1("V")

      entry_count.times.each_with_object({}) do |index, values|
        offset = 20 + (index * 16)
        key_offset, _format, value_length, _max_length, value_offset = bytes[offset, 16].unpack("vvVVV")

        key = bytes[(key_table_start + key_offset)..].split("\x00", 2).first
        raw_value = bytes[(data_table_start + value_offset), value_length]
        values[key] = raw_value.delete("\x00")
      end
    end
  end
end
```

```ruby
# app/services/title_id/iso_image.rb
module TitleId
  class IsoImage
    SECTOR_SIZE = 2048

    def initialize(param_sfo: ParamSfo.new)
      @param_sfo = param_sfo
    end

    def call(path)
      File.open(path, "rb") do |io|
        directory = read_directory(io, root_record(io))
        ps3_game = directory.fetch("PS3_GAME")
        ps3_directory = read_directory(io, ps3_game)
        param_sfo_record = ps3_directory.fetch("PARAM.SFO")

        io.seek(param_sfo_record[:extent] * SECTOR_SIZE)
        @param_sfo.call(io.read(param_sfo_record[:size]))
      end
    end

    private

    def root_record(io)
      io.seek(16 * SECTOR_SIZE)
      sector = io.read(SECTOR_SIZE)
      raise ArgumentError, "invalid ISO9660 header" unless sector[1, 5] == "CD001"

      parse_record(sector[156, 34])
    end

    def read_directory(io, record)
      io.seek(record[:extent] * SECTOR_SIZE)
      data = io.read(record[:size])
      entries = {}
      cursor = 0

      while cursor < data.bytesize
        length = data.getbyte(cursor)
        break if length.nil? || length.zero?

        entry = parse_record(data[cursor, length])
        cursor += length

        next if ["", ".", ".."].include?(entry[:name])

        entries[entry[:name]] = entry
      end

      entries
    end

    def parse_record(bytes)
      extent = bytes[2, 4].unpack1("V")
      size = bytes[10, 4].unpack1("V")
      name_length = bytes.getbyte(32)
      name = bytes[33, name_length]
      normalized_name = case name
                        when "\x00" then "."
                        when "\x01" then ".."
                        else name.delete("\x00").sub(/;1\z/, "")
                        end

      { extent: extent, size: size, name: normalized_name }
    end
  end
end
```

```ruby
# app/services/title_id/extractor.rb
module TitleId
  class Extractor
    SERIAL_REGEX = /([A-Z]{4}\d{5})/

    def initialize(pkg_header: PkgHeader.new, iso_image: IsoImage.new)
      @pkg_header = pkg_header
      @iso_image = iso_image
    end

    def call(path)
      filename_match(path) || pkg_match(path) || iso_match(path)
    end

    private

    attr_reader :pkg_header, :iso_image

    def filename_match(path)
      [File.basename(path), File.basename(File.dirname(path))].each do |candidate|
        match = candidate.match(SERIAL_REGEX)
        return match[1] if match
      end

      nil
    end

    def pkg_match(path)
      return unless File.extname(path).casecmp(".pkg").zero?

      pkg_header.call(path)
    end

    def iso_match(path)
      return unless File.extname(path).casecmp(".iso").zero?

      iso_image.call(path).fetch("TITLE_ID", nil)
    rescue KeyError, ArgumentError
      nil
    end
  end
end
```

- [ ] **Step 4: Run the ISO test suite again**

Run: `bin/rails test test/services/title_id/iso_image_test.rb test/services/title_id/extractor_test.rb`

Expected: PASS

- [ ] **Step 5: Commit the ISO fallback**

```bash
git add app/services/title_id test/services/title_id
git commit -m "feat: extract title ids from PS3 iso metadata"
```

### Task 5: Cache and query the GameTDB catalog

**Files:**
- Modify: `Gemfile`
- Create: `app/services/game_tdb/sync.rb`
- Create: `app/services/game_tdb/catalog.rb`
- Create: `app/services/game_tdb/cover_cache.rb`
- Test: `test/services/game_tdb/sync_test.rb`
- Test: `test/services/game_tdb/catalog_test.rb`
- Test: `test/services/game_tdb/cover_cache_test.rb`

- [ ] **Step 1: Write the failing GameTDB tests**

```ruby
# test/services/game_tdb/sync_test.rb
require "test_helper"

class GameTdbSyncTest < ActiveSupport::TestCase
  test "keeps using the cached xml when refresh fails" do
    Dir.mktmpdir do |dir|
      xml_path = Pathname(dir).join("ps3tdb.xml")
      xml_path.write("cached-data")
      xml_path.utime(2.days.ago, 2.days.ago)

      sync = GameTdb::Sync.new(
        cache_dir: dir,
        refresh_hours: 1,
        fetcher: ->(_uri) { raise SocketError, "offline" }
      )

      assert_equal xml_path, sync.ensure_current!
      assert_equal "cached-data", xml_path.read
    end
  end
end
```

```ruby
# test/services/game_tdb/catalog_test.rb
require "test_helper"

class GameTdbCatalogTest < ActiveSupport::TestCase
  test "looks up a title by id and searches by name" do
    Dir.mktmpdir do |dir|
      xml_path = File.join(dir, "ps3tdb.xml")
      File.write(xml_path, <<~XML)
        <datafile>
          <game name="God of War III">
            <id>BLUS30490</id>
            <region>US</region>
            <type>disc</type>
            <locale lang="EN">
              <title>God of War III</title>
            </locale>
          </game>
          <game name="Demon's Souls">
            <id>BLES00932</id>
            <region>EU</region>
            <type>disc</type>
            <locale lang="EN">
              <title>Demon's Souls</title>
            </locale>
          </game>
        </datafile>
      XML

      catalog = GameTdb::Catalog.new(xml_path: xml_path)

      assert_equal({ title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc" }, catalog.lookup("BLUS30490"))
      assert_equal ["Demon's Souls"], catalog.search("souls").map { |entry| entry.fetch(:name) }
    end
  end
end
```

```ruby
# test/services/game_tdb/cover_cache_test.rb
require "test_helper"

class GameTdbCoverCacheTest < ActiveSupport::TestCase
  test "downloads and stores a cover once" do
    Dir.mktmpdir do |dir|
      cache = GameTdb::CoverCache.new(cache_dir: Pathname(dir), fetcher: ->(_url) { "image-bytes" })

      path = cache.fetch!(title_id: "BLUS30490", region: "US")

      assert_equal Pathname(dir).join("BLUS30490.jpg"), path
      assert_equal "image-bytes", File.binread(path)
    end
  end
end
```

- [ ] **Step 2: Run the GameTDB tests to verify they fail**

Run: `bin/rails test test/services/game_tdb/sync_test.rb test/services/game_tdb/catalog_test.rb test/services/game_tdb/cover_cache_test.rb`

Expected: FAIL with `uninitialized constant GameTdb`.

- [ ] **Step 3: Add the XML and ZIP dependencies**

```ruby
# Gemfile
gem "nokogiri"
gem "rubyzip"
```

Run: `bundle install`

Expected: Bundler installs both gems and updates `Gemfile.lock`.

- [ ] **Step 4: Implement the GameTDB sync, lookup, search, and cover cache**

```ruby
# app/services/game_tdb/sync.rb
require "net/http"
require "zip"

module GameTdb
  class Sync
    def initialize(cache_dir: Rails.configuration.x.gametdb_cache_dir, archive_url: Rails.configuration.x.gametdb_archive_url, refresh_hours: Rails.configuration.x.gametdb_refresh_hours, fetcher: nil)
      @cache_dir = Pathname(cache_dir)
      @archive_url = archive_url
      @refresh_hours = refresh_hours
      @fetcher = fetcher || method(:default_fetch)
    end

    def ensure_current!
      FileUtils.mkdir_p(cache_dir)
      return xml_path if fresh?

      Zip::File.open_buffer(fetcher.call(URI.parse(archive_url))) do |zip_file|
        entry = zip_file.glob("ps3tdb.xml").first
        raise "ps3tdb.xml missing from archive" unless entry

        File.binwrite(xml_path, entry.get_input_stream.read)
      end

      xml_path
    rescue StandardError
      return xml_path if xml_path.exist?

      raise
    end

    private

    attr_reader :cache_dir, :archive_url, :refresh_hours, :fetcher

    def xml_path
      cache_dir.join("ps3tdb.xml")
    end

    def fresh?
      xml_path.exist? && xml_path.mtime > refresh_hours.hours.ago
    end

    def default_fetch(uri)
      Net::HTTP.get(uri)
    end
  end
end
```

```ruby
# app/services/game_tdb/catalog.rb
require "nokogiri"

module GameTdb
  class Catalog
    def initialize(xml_path: Sync.new.ensure_current!)
      @xml_path = xml_path
    end

    def lookup(title_id)
      game = document.at_xpath("//game[id='#{title_id}']")
      game && extract_entry(game)
    end

    def search(query, limit: 20)
      needle = query.to_s.downcase
      return [] if needle.blank?

      document.xpath("//game").filter_map do |game|
        entry = extract_entry(game)
        entry if entry.fetch(:name).downcase.include?(needle)
      end.first(limit)
    end

    private

    attr_reader :xml_path

    def document
      @document ||= Nokogiri::XML(File.read(xml_path))
    end

    def extract_entry(game)
      title_id = game.at_xpath("id").text

      {
        title_id: title_id,
        name: game.at_xpath("locale/title")&.text.presence || game["name"],
        region: game.at_xpath("region")&.text.presence || region_from_title_id(title_id),
        kind: game.at_xpath("type")&.text.to_s.downcase == "psn" ? "psn" : "disc"
      }
    end

    def region_from_title_id(title_id)
      case title_id
      when /\A(BLUS|BCUS|NPUB|NPUA)/ then "US"
      when /\A(BLES|BCES|NPEB|NPEA)/ then "EU"
      when /\A(BLJM|BCJS|NPJB|NPJA)/ then "JP"
      else "EN"
      end
    end
  end
end
```

```ruby
# app/services/game_tdb/cover_cache.rb
require "net/http"

module GameTdb
  class CoverCache
    def initialize(cache_dir: Rails.configuration.x.cover_cache_dir, fetcher: nil)
      @cache_dir = Pathname(cache_dir)
      @fetcher = fetcher || method(:default_fetch)
    end

    def fetch!(title_id:, region:)
      FileUtils.mkdir_p(cache_dir)
      destination = cache_dir.join("#{title_id}.jpg")
      return destination if destination.exist?

      bytes = fetcher.call(URI.parse("https://art.gametdb.com/ps3/cover/#{region}/#{title_id}.jpg"))
      File.binwrite(destination, bytes)
      destination
    end

    private

    attr_reader :cache_dir, :fetcher

    def default_fetch(uri)
      Net::HTTP.get(uri)
    end
  end
end
```

- [ ] **Step 5: Run the GameTDB tests again**

Run: `bin/rails test test/services/game_tdb/sync_test.rb test/services/game_tdb/catalog_test.rb test/services/game_tdb/cover_cache_test.rb`

Expected: PASS

- [ ] **Step 6: Commit the cached metadata layer**

```bash
git add Gemfile Gemfile.lock app/services/game_tdb test/services/game_tdb
git commit -m "feat: cache and query GameTDB metadata locally"
```

### Task 6: Scan the NAS and upsert catalog records

**Files:**
- Create: `app/services/library/scanner.rb`
- Test: `test/services/library/scanner_test.rb`

- [ ] **Step 1: Write the failing scanner test**

```ruby
# test/services/library/scanner_test.rb
require "test_helper"

class LibraryScannerTest < ActiveSupport::TestCase
  FakeCatalog = Struct.new(:entries) do
    def lookup(title_id)
      entries[title_id]
    end
  end

  FakeCoverCache = Struct.new(:downloads) do
    def fetch!(title_id:, region:)
      downloads << [title_id, region]
      Pathname("/covers/#{title_id}.jpg")
    end
  end

  test "creates media files, links games, and marks unseen files missing" do
    missing_game = Game.create!(title_id: "BLES00682", name: "Old", region: "EU", kind: "disc")
    MediaFile.create!(path: "/nas/old.pkg", file_format: "pkg", byte_size: 1, title_id: missing_game.title_id, game: missing_game, present: true, first_seen_at: 2.days.ago, last_seen_at: 2.days.ago)

    Dir.mktmpdir do |dir|
      File.binwrite(File.join(dir, "BLUS30490-God of War III.iso"), "iso")
      File.binwrite(File.join(dir, "mystery.pkg"), "\x00" * 32 + "EP9000-BLES00682_00-GAME00000000001" + "\x00" * 32)

      catalog = FakeCatalog.new(
        "BLUS30490" => { title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc" },
        "BLES00682" => { title_id: "BLES00682", name: "Demon's Souls", region: "EU", kind: "disc" }
      )

      scanner = Library::Scanner.new(
        nas_path: dir,
        extractor: TitleId::Extractor.new,
        catalog: catalog,
        cover_cache: FakeCoverCache.new([])
      )

      scan = Scan.create!(status: "running", started_at: Time.current, summary: "Queued")
      scanner.call(scan: scan)

      assert_equal 2, MediaFile.present_now.count
      assert_equal 1, MediaFile.missing.count
      assert_equal ["BLUS30490", "BLES00682"], Game.order(:title_id).pluck(:title_id)
      assert_equal "completed", scan.reload.status
    end
  end

  test "continues scanning when cover downloads fail" do
    Dir.mktmpdir do |dir|
      File.binwrite(File.join(dir, "BLUS30490-God of War III.iso"), "iso")

      catalog = FakeCatalog.new(
        "BLUS30490" => { title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc" }
      )
      failing_cover_cache = Object.new
      failing_cover_cache.define_singleton_method(:fetch!) do |**|
        raise SocketError, "art host offline"
      end

      scanner = Library::Scanner.new(
        nas_path: dir,
        extractor: TitleId::Extractor.new,
        catalog: catalog,
        cover_cache: failing_cover_cache
      )

      scan = Scan.create!(status: "running", started_at: Time.current, summary: "Queued")
      scanner.call(scan: scan)

      assert_equal "completed", scan.reload.status
      assert_equal "BLUS30490", MediaFile.find_by!(path: File.join(dir, "BLUS30490-God of War III.iso")).title_id
      assert_nil Game.find_by!(title_id: "BLUS30490").cover_path
    end
  end
end
```

The scanner should still save `media_files` and `games` when metadata refreshes or cover downloads fail; only the optional `cover_path` stays blank until a later retry succeeds.

- [ ] **Step 2: Run the scanner test to verify it fails**

Run: `bin/rails test test/services/library/scanner_test.rb`

Expected: FAIL with `uninitialized constant Library`.

- [ ] **Step 3: Implement the NAS scanner service**

```ruby
# app/services/library/scanner.rb
module Library
  class Scanner
    class NasUnavailable < StandardError; end

    def initialize(nas_path: Rails.configuration.x.nas_path, extractor: TitleId::Extractor.new, catalog: nil, cover_cache: nil)
      @nas_path = Pathname(nas_path)
      @extractor = extractor
      @catalog = catalog
      @cover_cache = cover_cache || GameTdb::CoverCache.new
    end

    def call(scan:)
      raise NasUnavailable, "NAS share not mounted at #{nas_path}" unless nas_path.directory? && nas_path.readable?

      seen_paths = []
      errors = 0
      files_found = 0

      each_media_file.with_index(1) do |path, index|
        files_found += 1
        seen_paths << path.to_s

        begin
          upsert_media_file!(path)
        rescue StandardError => error
          errors += 1
          Rails.logger.warn("scan failed for #{path}: #{error.message}")
        end

        yield(path.to_s, index) if block_given?
      end

      MediaFile.where.not(path: seen_paths).update_all(present: false)
      scan.complete!(files_found: files_found, errors_count: errors, summary: "Scanned #{files_found} files with #{errors} errors")
    end

    private

    attr_reader :nas_path, :extractor, :cover_cache

    def each_media_file
      Dir.glob(nas_path.join("**", "*").to_s, File::FNM_CASEFOLD).filter_map do |path|
        next unless File.file?(path)
        next unless %w[.iso .pkg].include?(File.extname(path).downcase)

        Pathname(path)
      end
    end

    def upsert_media_file!(path)
      now = Time.current
      title_id = extractor.call(path.to_s)
      media_file = MediaFile.find_or_initialize_by(path: path.to_s)

      media_file.assign_attributes(
        file_format: File.extname(path).delete(".").downcase,
        byte_size: path.size,
        title_id: title_id,
        present: true,
        first_seen_at: media_file.first_seen_at || now,
        last_seen_at: now
      )

      if title_id.present?
        entry = catalog.lookup(title_id)
        if entry
          game = Game.upsert_from_catalog!(title_id: title_id, entry: entry)
          attach_cover(game)
          media_file.game = game
        end
      end

      media_file.save!
    end

    def attach_cover(game)
      return if game.cover_path.present?

      cached_cover = cover_cache.fetch!(title_id: game.title_id, region: game.region)
      game.update!(cover_path: cached_cover.to_s) if cached_cover
    rescue StandardError => error
      Rails.logger.warn("cover fetch failed for #{game.title_id}: #{error.message}")
    end

    def catalog
      @catalog ||= GameTdb::Catalog.new
    rescue StandardError => error
      Rails.logger.warn("metadata lookup unavailable: #{error.message}")
      NullCatalog.new
    end

    class NullCatalog
      def lookup(_title_id)
        nil
      end
    end
  end
end
```

- [ ] **Step 4: Run the scanner test again**

Run: `bin/rails test test/services/library/scanner_test.rb`

Expected: PASS

- [ ] **Step 5: Commit the scanning service**

```bash
git add app/services/library test/services/library
git commit -m "feat: scan NAS files into the PS3 catalog"
```

### Task 7: Run scans in the background and broadcast progress

**Files:**
- Create: `app/jobs/scan_job.rb`
- Create: `app/controllers/scans_controller.rb`
- Modify: `app/controllers/dashboard_controller.rb`
- Modify: `app/views/dashboard/index.html.erb`
- Create: `app/views/scans/_scan_status.html.erb`
- Modify: `config/routes.rb`
- Test: `test/jobs/scan_job_test.rb`
- Test: `test/controllers/scans_controller_test.rb`
- Test: `test/system/scan_progress_test.rb`

- [ ] **Step 1: Write the failing job and controller tests**

```ruby
# test/jobs/scan_job_test.rb
require "test_helper"

class ScanJobTest < ActiveJob::TestCase
  test "marks the scan complete" do
    scan = Scan.create!(status: "running", started_at: Time.current, summary: "Queued")
    fake_scanner = Object.new
    fake_scanner.define_singleton_method(:call) do |scan:, &|
      scan.complete!(files_found: 2, errors_count: 0, summary: "Done")
    end

    Library::Scanner.stub(:new, fake_scanner) do
      perform_enqueued_jobs { ScanJob.perform_later(scan.id) }
    end

    assert_equal "completed", scan.reload.status
    assert_equal 2, scan.files_found
  end
end
```

```ruby
# test/controllers/scans_controller_test.rb
require "test_helper"

class ScansControllerTest < ActionDispatch::IntegrationTest
  test "queues a scan and redirects home" do
    assert_enqueued_with(job: ScanJob) do
      post scans_url
    end

    assert_redirected_to root_url
    assert_equal "running", Scan.order(:created_at).last.status
  end
end
```

```ruby
# test/system/scan_progress_test.rb
require "application_system_test_case"

class ScanProgressTest < ApplicationSystemTestCase
  test "starting a scan updates the dashboard status" do
    fake_scanner = Object.new
    fake_scanner.define_singleton_method(:call) do |scan:, &block|
      block.call("/nas/BLUS30490-God of War III.iso", 1)
      scan.complete!(files_found: 1, errors_count: 0, summary: "Scanned 1 files with 0 errors")
    end

    Library::Scanner.stub(:new, fake_scanner) do
      perform_enqueued_jobs do
        visit root_path
        click_button "Scan now"

        assert_text "Scanned 1 files with 0 errors"
      end
    end
  end
end
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `bin/rails test test/jobs/scan_job_test.rb test/controllers/scans_controller_test.rb && bin/rails test:system test/system/scan_progress_test.rb`

Expected: FAIL because the job and route do not exist.

- [ ] **Step 3: Implement the job, scan trigger, and dashboard progress partial**

```ruby
# app/jobs/scan_job.rb
class ScanJob < ApplicationJob
  queue_as :default

  def perform(scan_id)
    scan = Scan.find(scan_id)

    Library::Scanner.new.call(scan: scan) do |current_path, files_processed|
      Turbo::StreamsChannel.broadcast_replace_to(
        "scan_status",
        target: "scan_status",
        partial: "scans/scan_status",
        locals: { scan: scan, current_path: current_path, files_processed: files_processed }
      )
    end

    Turbo::StreamsChannel.broadcast_replace_to(
      "scan_status",
      target: "scan_status",
      partial: "scans/scan_status",
      locals: { scan: scan.reload, current_path: nil, files_processed: scan.files_found }
    )
  rescue StandardError => error
    scan&.fail!(summary: error.message)
    raise
  end
end
```

```ruby
# app/controllers/scans_controller.rb
class ScansController < ApplicationController
  def create
    scan = Scan.create!(status: "running", started_at: Time.current, summary: "Queued scan")
    ScanJob.perform_later(scan.id)

    redirect_to root_path, notice: "Scan queued"
  end
end
```

```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index
    @last_scan = Scan.recent_first.first
    @owned_count = Game.owned.count
    @wishlist_count = WishlistItem.count
    @missing_count = MediaFile.missing.count
    @unidentified_count = MediaFile.unidentified.count
  end
end
```

```ruby
# config/routes.rb
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"
  resources :scans, only: :create
  resources :library, only: :index
  resources :covers, only: :show
  resources :missing_media_files, only: :index
  resources :unidentified_media_files, only: :index
  resources :media_file_identifications, only: :update
  resources :wishlist_items, only: [:index, :create, :update, :destroy]
  resources :wishlist_searches, only: :index
end
```

```erb
<!-- app/views/scans/_scan_status.html.erb -->
<section id="scan_status" class="rounded border border-slate-200 bg-white p-4 shadow-sm">
  <div class="flex items-center justify-between">
    <div>
      <h2 class="text-lg font-semibold">Last scan</h2>
      <p class="text-sm text-slate-600"><%= scan&.summary.presence || "No scans have run yet." %></p>
      <% if current_path.present? %>
        <p class="mt-2 text-xs text-slate-500">Scanning <%= files_processed %>: <%= current_path %></p>
      <% end %>
    </div>
    <%= button_to "Scan now", scans_path, class: "rounded bg-slate-900 px-4 py-2 text-white" %>
  </div>
</section>
```

```erb
<!-- app/views/dashboard/index.html.erb -->
<%= turbo_stream_from "scan_status" %>

<div class="mx-auto flex max-w-5xl flex-col gap-6 px-4 py-8">
  <header class="flex items-center justify-between">
    <div>
      <h1 class="text-3xl font-bold">PS3 Game Manager</h1>
      <p class="text-slate-600">Track owned games, missing files, and wishlist matches from one NAS scan.</p>
    </div>
  </header>

  <nav class="flex gap-4 text-sm font-medium text-slate-700">
    <%= link_to "Library", library_index_path %>
    <%= link_to "Wishlist", wishlist_items_path %>
    <%= link_to "Missing", missing_media_files_path %>
    <%= link_to "Unidentified", unidentified_media_files_path %>
  </nav>

  <section class="grid gap-4 md:grid-cols-4">
    <div class="rounded border border-slate-200 bg-white p-4 shadow-sm"><p class="text-sm text-slate-500">Owned</p><p class="text-2xl font-bold"><%= @owned_count %></p></div>
    <div class="rounded border border-slate-200 bg-white p-4 shadow-sm"><p class="text-sm text-slate-500">Wishlist</p><p class="text-2xl font-bold"><%= @wishlist_count %></p></div>
    <div class="rounded border border-slate-200 bg-white p-4 shadow-sm"><p class="text-sm text-slate-500">Missing</p><p class="text-2xl font-bold"><%= @missing_count %></p></div>
    <div class="rounded border border-slate-200 bg-white p-4 shadow-sm"><p class="text-sm text-slate-500">Unidentified</p><p class="text-2xl font-bold"><%= @unidentified_count %></p></div>
  </section>

  <%= render "scans/scan_status", scan: @last_scan, current_path: nil, files_processed: 0 %>
</div>
```

- [ ] **Step 4: Run the job and controller tests again**

Run: `bin/rails test test/jobs/scan_job_test.rb test/controllers/scans_controller_test.rb && bin/rails test:system test/system/scan_progress_test.rb`

Expected: PASS

- [ ] **Step 5: Commit the background scan flow**

```bash
git add app/jobs app/controllers app/views/scans app/views/dashboard config/routes.rb test/jobs test/controllers
git commit -m "feat: enqueue manual scans and stream progress"
```

### Task 8: Build the owned, missing, and unidentified pages

**Files:**
- Create: `app/controllers/library_controller.rb`
- Create: `app/controllers/covers_controller.rb`
- Create: `app/controllers/missing_media_files_controller.rb`
- Create: `app/controllers/unidentified_media_files_controller.rb`
- Create: `app/controllers/media_file_identifications_controller.rb`
- Create: `app/views/library/index.html.erb`
- Create: `app/views/missing_media_files/index.html.erb`
- Create: `app/views/unidentified_media_files/index.html.erb`
- Modify: `config/routes.rb`
- Test: `test/controllers/covers_controller_test.rb`
- Test: `test/controllers/library_controller_test.rb`
- Test: `test/controllers/media_file_identifications_controller_test.rb`
- Test: `test/system/library_browse_test.rb`

- [ ] **Step 1: Write the failing browse and manual-identification tests**

```ruby
# test/controllers/covers_controller_test.rb
require "test_helper"

class CoversControllerTest < ActionDispatch::IntegrationTest
  test "streams a cached cover from disk" do
    Dir.mktmpdir do |dir|
      cover_path = File.join(dir, "BLUS30490.jpg")
      File.binwrite(cover_path, "cover-bytes")
      game = Game.create!(title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc", cover_path: cover_path)

      get cover_url(game)

      assert_response :success
      assert_equal "cover-bytes", @response.body
    end
  end
end
```

```ruby
# test/controllers/library_controller_test.rb
require "test_helper"

class LibraryControllerTest < ActionDispatch::IntegrationTest
  test "filters the owned library by region" do
    us_game = Game.create!(title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc")
    eu_game = Game.create!(title_id: "BLES00682", name: "Demon's Souls", region: "EU", kind: "disc")

    MediaFile.create!(path: "/nas/us.iso", file_format: "iso", byte_size: 1, title_id: us_game.title_id, game: us_game, present: true, first_seen_at: Time.current, last_seen_at: Time.current)
    MediaFile.create!(path: "/nas/eu.iso", file_format: "iso", byte_size: 1, title_id: eu_game.title_id, game: eu_game, present: true, first_seen_at: Time.current, last_seen_at: Time.current)

    get library_index_url, params: { region: "US" }

    assert_response :success
    assert_select "h2", "God of War III"
    assert_select "h2", text: "Demon's Souls", count: 0
  end
end
```

```ruby
# test/controllers/media_file_identifications_controller_test.rb
require "test_helper"

class MediaFileIdentificationsControllerTest < ActionDispatch::IntegrationTest
  test "updates an unidentified file with a manual title id" do
    media_file = MediaFile.create!(path: "/nas/unknown.iso", file_format: "iso", byte_size: 1, present: true, first_seen_at: Time.current, last_seen_at: Time.current)
    fake_catalog = Object.new
    fake_catalog.define_singleton_method(:lookup) do |_title_id|
      { title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc" }
    end

    GameTdb::Catalog.stub(:new, fake_catalog) do
      patch media_file_identification_url(media_file), params: { media_file: { title_id: "BLUS30490" } }
    end

    assert_redirected_to unidentified_media_files_url
    assert_equal "BLUS30490", media_file.reload.title_id
    assert_equal "God of War III", media_file.game.name
  end
end
```

```ruby
# test/system/library_browse_test.rb
require "application_system_test_case"

class LibraryBrowseTest < ApplicationSystemTestCase
  test "browsing the library and viewing missing files" do
    Dir.mktmpdir do |dir|
      cover_path = File.join(dir, "BLUS30490.jpg")
      File.binwrite(cover_path, "cover-bytes")
      game = Game.create!(title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc", cover_path: cover_path)
    MediaFile.create!(path: "/nas/present.iso", file_format: "iso", byte_size: 1, title_id: game.title_id, game: game, present: true, first_seen_at: Time.current, last_seen_at: Time.current)
    MediaFile.create!(path: "/nas/missing.iso", file_format: "iso", byte_size: 1, title_id: game.title_id, game: game, present: false, first_seen_at: Time.current, last_seen_at: Time.current)

      visit root_path
      click_link "Library"

      assert_text "God of War III"
      assert_selector "img[alt='God of War III cover']"

      click_link "Missing"
      assert_text "/nas/missing.iso"
    end
  end
end
```

- [ ] **Step 2: Run the browse tests to verify they fail**

Run: `bin/rails test test/controllers/covers_controller_test.rb test/controllers/library_controller_test.rb test/controllers/media_file_identifications_controller_test.rb && bin/rails test:system test/system/library_browse_test.rb`

Expected: FAIL because the routes and controllers do not exist.

- [ ] **Step 3: Implement the browse controllers, routes, and views**

```ruby
# config/routes.rb
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"
  resources :scans, only: :create
  resources :library, only: :index
  resources :missing_media_files, only: :index
  resources :unidentified_media_files, only: :index
  resources :covers, only: :show
  resources :media_file_identifications, only: :update
  resources :wishlist_items, only: [:index, :create, :update, :destroy]
  resources :wishlist_searches, only: :index
end
```

```ruby
# app/controllers/covers_controller.rb
class CoversController < ApplicationController
  def show
    game = Game.find(params[:id])

    if game.cover_path.present? && File.exist?(game.cover_path)
      send_file game.cover_path, disposition: "inline", type: "image/jpeg"
    else
      head :not_found
    end
  end
end
```

```ruby
# app/controllers/library_controller.rb
class LibraryController < ApplicationController
  def index
    scope = Game.owned.includes(:media_files).order(:name)
    scope = scope.where(region: params[:region]) if params[:region].present?
    scope = scope.where("games.name LIKE :q OR games.title_id LIKE :q", q: "%#{params[:q]}%") if params[:q].present?

    if params[:format].present?
      scope = scope.joins(:media_files).merge(MediaFile.present_now.where(file_format: params[:format]))
    end

    @games = scope.distinct
  end
end
```

```ruby
# app/controllers/missing_media_files_controller.rb
class MissingMediaFilesController < ApplicationController
  def index
    @media_files = MediaFile.missing.includes(:game).order(:path)
  end
end
```

```ruby
# app/controllers/unidentified_media_files_controller.rb
class UnidentifiedMediaFilesController < ApplicationController
  def index
    @media_files = MediaFile.unidentified.order(:path)
  end
end
```

```ruby
# app/controllers/media_file_identifications_controller.rb
class MediaFileIdentificationsController < ApplicationController
  def update
    media_file = MediaFile.find(params[:id])
    title_id = params.require(:media_file).fetch(:title_id)
    entry = GameTdb::Catalog.new.lookup(title_id)

    game = entry ? Game.upsert_from_catalog!(title_id: title_id, entry: entry) : nil
    media_file.update!(title_id: title_id, game: game)

    redirect_to unidentified_media_files_path, notice: "File updated"
  end
end
```

```erb
<!-- app/views/library/index.html.erb -->
<div class="mx-auto max-w-6xl space-y-6 px-4 py-8">
  <header class="flex items-center justify-between">
    <h1 class="text-3xl font-bold">Library</h1>
    <%= link_to "Back to dashboard", root_path, class: "text-sm text-slate-600" %>
  </header>

  <%= form_with url: library_index_path, method: :get, class: "grid gap-4 md:grid-cols-3" do |form| %>
    <%= form.text_field :q, value: params[:q], placeholder: "Search title or serial", class: "rounded border-slate-300" %>
    <%= form.select :region, options_for_select([["All regions", ""], ["US", "US"], ["EU", "EU"], ["JP", "JP"]], params[:region]), {}, class: "rounded border-slate-300" %>
    <%= form.select :format, options_for_select([["All formats", ""], ["ISO", "iso"], ["PKG", "pkg"]], params[:format]), {}, class: "rounded border-slate-300" %>
  <% end %>

  <section class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
    <% @games.each do |game| %>
      <article class="rounded border border-slate-200 bg-white p-4 shadow-sm">
        <% if game.cover_path.present? %>
          <%= image_tag cover_path(game), alt: "#{game.name} cover", class: "mb-3 aspect-[2/3] w-full rounded object-cover" %>
        <% end %>
        <h2 class="text-lg font-semibold"><%= game.name %></h2>
        <p class="text-sm text-slate-500"><%= game.title_id %> · <%= game.region %> · <%= game.kind %></p>
      </article>
    <% end %>
  </section>
</div>
```

```erb
<!-- app/views/missing_media_files/index.html.erb -->
<div class="mx-auto max-w-5xl space-y-6 px-4 py-8">
  <h1 class="text-3xl font-bold">Missing Files</h1>

  <table class="min-w-full border-collapse text-left text-sm">
    <thead>
      <tr><th class="border-b px-2 py-2">Path</th><th class="border-b px-2 py-2">Game</th></tr>
    </thead>
    <tbody>
      <% @media_files.each do |media_file| %>
        <tr>
          <td class="border-b px-2 py-2"><%= media_file.path %></td>
          <td class="border-b px-2 py-2"><%= media_file.game&.name || media_file.title_id || "Unknown" %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

```erb
<!-- app/views/unidentified_media_files/index.html.erb -->
<div class="mx-auto max-w-5xl space-y-6 px-4 py-8">
  <h1 class="text-3xl font-bold">Unidentified Files</h1>

  <% @media_files.each do |media_file| %>
    <div class="rounded border border-amber-200 bg-amber-50 p-4">
      <p class="font-medium"><%= media_file.path %></p>
      <%= form_with model: media_file, url: media_file_identification_path(media_file), method: :patch, class: "mt-3 flex gap-3" do |form| %>
        <%= form.text_field :title_id, placeholder: "BLUS30490", class: "rounded border-slate-300" %>
        <%= form.submit "Save title ID", class: "rounded bg-slate-900 px-4 py-2 text-white" %>
      <% end %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 4: Run the browse tests again**

Run: `bin/rails test test/controllers/covers_controller_test.rb test/controllers/library_controller_test.rb test/controllers/media_file_identifications_controller_test.rb && bin/rails test:system test/system/library_browse_test.rb`

Expected: PASS

- [ ] **Step 5: Commit the browse and manual-fix flows**

```bash
git add app/controllers app/views/library app/views/missing_media_files app/views/unidentified_media_files config/routes.rb test/controllers test/system
git commit -m "feat: add library, missing, and unidentified views"
```

### Task 9: Build the wishlist search and ownership matching flow

**Files:**
- Create: `app/controllers/wishlist_items_controller.rb`
- Create: `app/controllers/wishlist_searches_controller.rb`
- Create: `app/views/wishlist_items/index.html.erb`
- Create: `app/views/wishlist_searches/_results.html.erb`
- Test: `test/controllers/wishlist_items_controller_test.rb`
- Test: `test/controllers/wishlist_searches_controller_test.rb`
- Test: `test/system/wishlist_management_test.rb`

- [ ] **Step 1: Write the failing wishlist tests**

```ruby
# test/controllers/wishlist_searches_controller_test.rb
require "test_helper"

class WishlistSearchesControllerTest < ActionDispatch::IntegrationTest
  test "returns matching GameTDB results" do
    fake_catalog = Object.new
    fake_catalog.define_singleton_method(:search) do |_query|
      [{ title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc" }]
    end

    GameTdb::Catalog.stub(:new, fake_catalog) do
      get wishlist_searches_url, params: { q: "war" }
    end

    assert_response :success
    assert_includes @response.body, "God of War III"
  end
end
```

```ruby
# test/controllers/wishlist_items_controller_test.rb
require "test_helper"

class WishlistItemsControllerTest < ActionDispatch::IntegrationTest
  test "creates a wishlist item from a GameTDB title id" do
    fake_catalog = Object.new
    fake_catalog.define_singleton_method(:lookup) do |_title_id|
      { title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc" }
    end

    GameTdb::Catalog.stub(:new, fake_catalog) do
      post wishlist_items_url, params: { title_id: "BLUS30490", notes: "look for a clean rip", priority: 5 }
    end

    item = WishlistItem.order(:created_at).last
    assert_redirected_to wishlist_items_url
    assert_equal "BLUS30490", item.game.title_id
    assert_equal 5, item.priority
  end
end
```

```ruby
# test/system/wishlist_management_test.rb
require "application_system_test_case"

class WishlistManagementTest < ApplicationSystemTestCase
  test "searching and adding a wishlist entry" do
    fake_catalog = Object.new
    fake_catalog.define_singleton_method(:search) do |_query|
      [{ title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc" }]
    end
    fake_catalog.define_singleton_method(:lookup) do |_title_id|
      { title_id: "BLUS30490", name: "God of War III", region: "US", kind: "disc" }
    end

    GameTdb::Catalog.stub(:new, fake_catalog) do
      visit wishlist_items_path
      fill_in "q", with: "war"
      click_button "Search"
      click_button "Add God of War III"

      assert_text "God of War III"
    end
  end
end
```

- [ ] **Step 2: Run the wishlist tests to verify they fail**

Run: `bin/rails test test/controllers/wishlist_searches_controller_test.rb test/controllers/wishlist_items_controller_test.rb && bin/rails test:system test/system/wishlist_management_test.rb`

Expected: FAIL because the wishlist controllers and views do not exist.

- [ ] **Step 3: Implement the wishlist search, add, list, and owned badge flow**

```ruby
# app/controllers/wishlist_items_controller.rb
class WishlistItemsController < ApplicationController
  def index
    @wishlist_items = WishlistItem.includes(:game).ordered
  end

  def create
    entry = GameTdb::Catalog.new.lookup(params.fetch(:title_id))
    game = Game.upsert_from_catalog!(title_id: entry.fetch(:title_id), entry: entry)

    WishlistItem.find_or_create_by!(game: game) do |item|
      item.notes = params.fetch(:notes, "")
      item.priority = params.fetch(:priority, 0)
    end

    redirect_to wishlist_items_path, notice: "Wishlist updated"
  end

  def update
    wishlist_item = WishlistItem.find(params[:id])
    wishlist_item.update!(params.require(:wishlist_item).permit(:notes, :priority))

    redirect_to wishlist_items_path, notice: "Wishlist item updated"
  end

  def destroy
    WishlistItem.find(params[:id]).destroy!
    redirect_to wishlist_items_path, notice: "Wishlist item removed"
  end
end
```

```ruby
# app/controllers/wishlist_searches_controller.rb
class WishlistSearchesController < ApplicationController
  def index
    @results = GameTdb::Catalog.new.search(params[:q])

    render partial: "wishlist_searches/results", locals: { results: @results }
  end
end
```

```erb
<!-- app/views/wishlist_items/index.html.erb -->
<div class="mx-auto max-w-5xl space-y-6 px-4 py-8">
  <header class="flex items-center justify-between">
    <h1 class="text-3xl font-bold">Wishlist</h1>
    <%= link_to "Back to dashboard", root_path, class: "text-sm text-slate-600" %>
  </header>

  <%= form_with url: wishlist_searches_path, method: :get, data: { turbo_frame: "wishlist_results" }, class: "flex gap-3" do |form| %>
    <%= form.text_field :q, placeholder: "Search GameTDB", class: "w-full rounded border-slate-300" %>
    <%= form.submit "Search", class: "rounded bg-slate-900 px-4 py-2 text-white" %>
  <% end %>

  <turbo-frame id="wishlist_results"></turbo-frame>

  <section class="space-y-4">
    <% @wishlist_items.each do |wishlist_item| %>
      <article class="rounded border border-slate-200 bg-white p-4 shadow-sm">
        <div class="flex items-center justify-between">
          <div>
            <h2 class="text-lg font-semibold"><%= wishlist_item.game.name %></h2>
            <p class="text-sm text-slate-500"><%= wishlist_item.game.title_id %> · priority <%= wishlist_item.priority %></p>
          </div>
          <% if wishlist_item.owned? %>
            <span class="rounded bg-emerald-100 px-2 py-1 text-xs font-medium text-emerald-700">Now owned</span>
          <% end %>
        </div>
        <p class="mt-2 text-sm text-slate-600"><%= wishlist_item.notes %></p>
      </article>
    <% end %>
  </section>
</div>
```

```erb
<!-- app/views/wishlist_searches/_results.html.erb -->
<turbo-frame id="wishlist_results">
  <div class="space-y-3 rounded border border-slate-200 bg-white p-4 shadow-sm">
    <% results.each do |result| %>
      <div class="flex items-center justify-between border-b border-slate-100 pb-3 last:border-b-0 last:pb-0">
        <div>
          <p class="font-medium"><%= result.fetch(:name) %></p>
          <p class="text-sm text-slate-500"><%= result.fetch(:title_id) %> · <%= result.fetch(:region) %></p>
        </div>
        <%= button_to "Add #{result.fetch(:name)}", wishlist_items_path(title_id: result.fetch(:title_id)), class: "rounded bg-slate-900 px-3 py-2 text-sm text-white" %>
      </div>
    <% end %>
  </div>
</turbo-frame>
```

- [ ] **Step 4: Run the wishlist tests again**

Run: `bin/rails test test/controllers/wishlist_searches_controller_test.rb test/controllers/wishlist_items_controller_test.rb && bin/rails test:system test/system/wishlist_management_test.rb`

Expected: PASS

- [ ] **Step 5: Commit the wishlist flow**

```bash
git add app/controllers/wishlist_* app/views/wishlist_* test/controllers/wishlist_* test/system/wishlist_management_test.rb
git commit -m "feat: add wishlist search and ownership matching"
```

### Task 10: Finalize Docker deployment and project documentation

**Files:**
- Modify: `Dockerfile`
- Create: `.dockerignore`
- Create: `docker-compose.yml`
- Modify: `bin/docker-entrypoint`
- Create: `README.md`

- [ ] **Step 1: Write the container and compose files**

```dockerfile
# Dockerfile
FROM ruby:3.3-slim AS base

WORKDIR /rails

RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential curl git libsqlite3-0 libsqlite3-dev pkg-config && rm -rf /var/lib/apt/lists/*

ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

ENTRYPOINT ["./bin/docker-entrypoint"]
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
```

```text
# .dockerignore
/.git
/log/*
/tmp/*
/storage/*
!/storage/.keep
/node_modules
```

```yaml
# docker-compose.yml
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      RAILS_ENV: production
      SECRET_KEY_BASE: replace-me
      NAS_PATH: /nas
      GAMETDB_REFRESH_HOURS: 24
    volumes:
      - ps3_data:/rails/storage
      - /mnt/ps3:/nas:ro
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/up"]
      interval: 30s
      timeout: 5s
      retries: 3

volumes:
  ps3_data:
```

```sh
# bin/docker-entrypoint
#!/bin/sh
set -e

./bin/rails db:prepare
./bin/jobs start &

exec "$@"
```

- [ ] **Step 2: Document local setup and Raspberry Pi deployment**

~~~markdown
# README.md

## PS3 Game Manager

Rails 8 app for tracking PS3 `.iso` and `.pkg` backups stored on a NAS.

## Local setup

~~~bash
bundle install
bin/rails db:prepare
bin/dev
~~~

## Running tests

~~~bash
bin/rails test
bin/rails test:system
~~~

## Docker deployment

1. Mount the NAS share on the Raspberry Pi host at `/mnt/ps3`.
2. Set a real `SECRET_KEY_BASE` in `docker-compose.yml` or an `.env` file.
3. Start the app with `docker compose up --build -d`.
4. Open `http://<pi-address>:3000`.
~~~

- [ ] **Step 3: Verify the production config and the full test suite**

Run: `docker compose config && bin/rails test && bin/rails test:system`

Expected: `docker compose config` prints a valid service definition, unit tests pass, and system tests pass.

- [ ] **Step 4: Commit the deployment and documentation changes**

```bash
git add Dockerfile .dockerignore docker-compose.yml bin/docker-entrypoint README.md
git commit -m "feat: package PS3 manager for Raspberry Pi deployment"
```

## Final Verification

- Run `bin/rails test`
- Run `bin/rails test:system`
- Run `docker compose config`
- Run `bin/brakeman`

The branch is ready once all four commands pass and a manual dashboard scan succeeds against a mounted test NAS directory.
