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

1. Mount the NAS share on the Raspberry Pi host at `/mnt/ps3`.
2. Set a real `SECRET_KEY_BASE` in `docker-compose.yml` or an `.env` file.
3. Start the app with `docker compose up --build -d`.
4. Open `http://<pi-address>:3000`.
