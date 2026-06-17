# PS3 Game Manager

Rails 8 app for tracking PS3 `.iso` and `.pkg` backups stored on a NAS.

## Local setup

```bash
bundle install
bin/rails db:prepare
bin/dev
```

## Running tests

```bash
bin/rails test
bin/rails test:system
```

## Docker deployment

1. Create a `.env` file next to `docker-compose.yml`.
2. Generate a real `SECRET_KEY_BASE` with `bin/rails secret`.
3. Set `SECRET_KEY_BASE` and `RAILS_MASTER_KEY` in `.env`.
4. Set `NAS_HOST_PATH` in `.env` if the NAS is not mounted at `/mnt/ps3` on the Docker host.
5. Start the app with `docker compose up --build -d`.
6. Open `http://localhost:3000` on the Docker host.

Example `.env`:

```env
SECRET_KEY_BASE=replace-with-bin-rails-secret
RAILS_MASTER_KEY=replace-with-config-master-key
NAS_HOST_PATH=//Synergy/Backups/PlayStation/Games
```

Notes:

- `NAS_HOST_PATH` defaults to `/mnt/ps3`, which matches the Raspberry Pi deployment setup.
- On Windows, use the `//server/share/path` format for network shares.
