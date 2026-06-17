# PS3 Game Manager — Design Document

**Date:** 2026-06-16
**Status:** Approved design, pending implementation plan

## 1. Purpose

A self-hosted web app that runs in Docker on a Raspberry Pi and helps manage a
PS3 backup collection stored on a NAS. It:

1. Scans a NAS share for PS3 backup `.iso` files and `.pkg` files and records
   what is already owned.
2. Identifies each file by its PS3 **Title ID**, then enriches it with a
   readable game name, region, and box art.
3. Tracks a **wishlist** of games the user wants but does not yet own, with
   automatic "you now own this" matching when a wanted title appears on the NAS.

### Non-goals (explicitly out of scope)

- Authentication / login (the app is LAN-only and trusts the home network).
- Multi-user accounts or per-user wishlists.
- Scheduled / cron-based scanning (scans are manual only).
- Postgres / Redis / Sidekiq (the Rails 8 "Solid" stack is used instead).
- Downloading or acquiring games (this is a tracker, not a downloader).
- PSN account integration.

## 2. Decisions (from brainstorming)

| Topic | Decision |
|-------|----------|
| NAS access | NAS SMB/NFS share is mounted at the OS level on the Pi and bind-mounted **read-only** into the container. The app reads a plain local path. |
| Metadata | Online enrichment: extract Title ID, then look up name/region/cover from GameTDB. Cached locally for offline use. |
| Wishlist input | Search the same GameTDB title database and add by Title ID, so owned-vs-wanted matching is automatic. |
| Scan trigger | Manual only ("Scan now" button), executed as a background job so the UI does not block. |
| Auth | None. LAN-only. A reverse-proxy password can be layered on later if desired. |
| Architecture | Rails 8 "Solid" all-in-one: single container, SQLite + Solid Queue + Hotwire. |

## 3. Architecture

A single Docker container (ARM64, targeting Raspberry Pi 4/5 64-bit) runs:

```
┌─────────────────── Docker container ───────────────────┐
│  Rails 8 (Puma)                                         │
│   ├─ Web UI (Hotwire / Turbo, server-rendered)          │
│   ├─ Solid Queue worker (runs in-process)               │
│   ├─ Services: Scanner / TitleID extractor / Metadata   │
│   └─ SQLite (app DB + Solid Queue + Solid Cache)        │
└──────┬─────────────────────────┬────────────────────────┘
   ro mount /nas            data volume
       │                    (sqlite db, cover cache, gametdb datafile)
       │
   NAS SMB/NFS share (mounted at OS level on the Pi host)
```

- **One service** in `docker-compose.yml`.
- **Two volumes:**
  - NAS share, bind-mounted read-only at `/nas`.
  - A persistent named volume for the SQLite databases, cached cover images,
    and the downloaded GameTDB datafile.
- Rationale: SQLite + Solid Queue + Solid Cache avoid running separate database
  and Redis daemons, keeping memory/CPU use low on the Pi. Single-writer SQLite
  is a non-issue for one-person LAN use.

## 4. Components

### 4.1 Scanner
Recursively walks `/nas`, filtering for `.iso` and `.pkg` files. For each file it
upserts a `media_files` row keyed by absolute path, updating `last_seen_at` and
`byte_size`. After the walk, any `media_files` row not seen during this run is
marked `present: false` (moved/deleted on the NAS).

### 4.2 TitleID Extractor
A strategy chain, stopping at the first success:

1. **Filename / folder regex** — match a PS3 serial of the form
   `[A-Z]{4}\d{5}` (e.g. `BLUS30490`, `NPEB01234`) in the filename or its
   parent folder name. Cheapest; works for well-named backups.
2. **PKG header read** (`.pkg` only) — read the package header and extract the
   `content_id` ASCII field (format like `EP9000-BLES00682_00-...`), from which
   the Title ID is derived. Requires reading only the first few dozen bytes.
3. **ISO PARAM.SFO fallback** (`.iso` only) — parse the ISO9660 filesystem to
   locate `PS3_GAME/PARAM.SFO` and read its `TITLE_ID` (and `TITLE`) keys. More
   involved; used only when the filename yields nothing.

Files that yield no Title ID are stored with `title_id: nil` and flagged
**unidentified** so the user can enter a Title ID manually.

### 4.3 Metadata Provider
Backed by **GameTDB**, which publishes both a downloadable PS3 title database
and box-art image URLs.

- The PS3 title datafile is downloaded once and cached on the data volume, then
  refreshed occasionally. Lookups (Title ID → name, region, kind) run against
  this local copy — few network calls, and it keeps working offline.
- Box art is fetched from GameTDB cover URLs on first need and cached to disk.
- If GameTDB is unreachable, the cached datafile and cached covers are used;
  missing covers are retried later. Metadata fetching never blocks a scan.

### 4.4 ScanJob (Solid Queue)
Enqueued by the "Scan now" button. Runs the full scan flow (Section 6) and
broadcasts progress to the browser via Turbo Streams (files scanned, current
path). Writes a `scans` summary record on completion.

## 5. Data model

### games
Canonical catalog entry, one per distinct title.

| Column | Notes |
|--------|-------|
| `title_id` | Unique. e.g. `BLUS30490`. |
| `name` | Human-readable title (from GameTDB). |
| `region` | e.g. US / EU / JP. |
| `kind` | `disc` or `psn`. |
| `cover_path` | Local path to cached box art (nullable). |
| timestamps | |

### media_files
One row per discovered file on the NAS.

| Column | Notes |
|--------|-------|
| `path` | Unique, absolute path under `/nas`. |
| `file_format` | `iso` or `pkg`. |
| `byte_size` | |
| `title_id` | Nullable until identified. |
| `game_id` | FK to `games`, nullable. |
| `present` | Boolean; `false` when not seen in the latest scan. |
| `first_seen_at`, `last_seen_at` | |

### wishlist_items
| Column | Notes |
|--------|-------|
| `game_id` / `title_id` | References the wanted title. |
| `notes` | Free text. |
| `priority` | Ordering / importance. |
| `created_at` | |

### scans
| Column | Notes |
|--------|-------|
| `status` | running / completed / failed. |
| `started_at`, `finished_at` | |
| `files_found` | |
| `errors_count` | |
| `summary` | Short result text. |

**Ownership is derived, not stored:** a game is "owned" when a `media_file` with
`present: true` references it. A wishlist item whose Title ID appears on the NAS
is therefore auto-flagged as now-owned.

## 6. Key flows

### Scan
1. User clicks **Scan now** → `ScanJob` is enqueued via Solid Queue.
2. Job walks `/nas`, filtering `.iso`/`.pkg`.
3. For each file: upsert `media_files` by path, set `last_seen_at`/`byte_size`,
   run the TitleID Extractor.
4. Mark `media_files` not seen this run as `present: false`.
5. For newly seen Title IDs: look up in the local GameTDB index, upsert `games`,
   fetch and cache cover art if missing.
6. Broadcast live progress via Turbo Streams.
7. Write the `scans` summary; refresh the dashboard.

### Wishlist
1. User searches in the add-to-wishlist box → query the local GameTDB index.
2. User picks a result → create a `wishlist_item` (linked by Title ID).
3. The wishlist view shows priority and a badge when an item is now owned
   (i.e. a matching `present: true` media file exists), prompting removal.

### Browse
- **Library** — grid of owned games with covers; filter by format/region; search.
- **Wishlist** — list ordered by priority, with now-owned badges.
- **Missing** — `media_files` with `present: false` (moved/deleted on the NAS).
- **Unidentified** — files with no Title ID, for manual entry.
- **Dashboard** — counts (owned / wishlist / missing / unidentified), last scan
  time, and the Scan now button.

## 7. Error handling

| Condition | Behavior |
|-----------|----------|
| NAS not mounted / `/nas` unreadable | Scan fails fast with a clear message ("NAS share not mounted at /nas"). |
| Unparseable file (no Title ID) | Stored with `title_id: nil`, flagged unidentified; scan continues. |
| Corrupt PKG/ISO header | Per-file error logged, counted in `errors_count`; scan continues. |
| GameTDB unreachable | Use cached datafile/covers; retry covers later; never block the scan. |

## 8. Testing strategy

- **Unit:** serial regex parser; PKG header parser (small byte-array fixtures);
  optional SFO parser; GameTDB index lookup; cover cache read/write.
- **Model:** ownership derivation; missing-file marking on rescan; wishlist →
  owned matching.
- **Job:** `ScanJob` run against a temporary directory of fixture files (tiny
  files carrying valid PKG headers — no real ISOs required).
- **System (Capybara):** scan flow with progress, add-to-wishlist search/add,
  library browsing/filtering.

## 9. Deployment

- **Image:** multi-stage Dockerfile producing an ARM64 image for Raspberry Pi
  4/5 (64-bit OS).
- **Compose:** single service; volumes for the read-only NAS bind mount (`/nas`)
  and the persistent data volume (SQLite DB, cover cache, GameTDB datafile).
- **Configuration (env):** `NAS_PATH` (default `/nas`), GameTDB datafile
  location/refresh settings, `RAILS_ENV=production`, `SECRET_KEY_BASE`.
- **Health check:** container healthcheck hitting a Rails health endpoint.
- The Pi host is responsible for mounting the NAS SMB/NFS share before the
  container starts.
