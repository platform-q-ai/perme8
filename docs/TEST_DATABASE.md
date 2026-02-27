# Test Database Setup

This project uses PostgreSQL for testing. A single PostgreSQL instance serves
both the `jarga_dev` and `jarga_test` databases on port 5432.

## Quick Start

### 1. Start PostgreSQL

```bash
docker-compose up -d
```

This starts one PostgreSQL container that automatically creates both the
`jarga_dev` (default) and `jarga_test` (via init script) databases.

### 2. Create and migrate the test database

```bash
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate
```

### 3. Run the tests

```bash
mix test
```

## Database Management

### Start the database
```bash
docker-compose up -d
```

### Stop the database
```bash
docker-compose down
```

### Stop and remove all data (clean slate)
```bash
docker-compose down -v
```

### View database logs
```bash
docker-compose logs -f postgres
```

### Check database status
```bash
docker-compose ps
```

## Database Configuration

Both dev and test databases run on the same PostgreSQL instance:

- **Host**: `localhost`
- **Port**: `5432`
- **User**: `postgres`
- **Password**: `postgres`
- **Dev database**: `jarga_dev`
- **Test database**: `jarga_test`

The test `DATABASE_URL` is provided by `.env.test` and loaded by `config/test.exs`.

## Troubleshooting

### Connection refused errors

If you see "connection refused" errors:

1. Make sure Docker is running
2. Start the database: `docker-compose up -d`
3. Wait a few seconds for PostgreSQL to start
4. Check the database is healthy: `docker-compose ps`

### Database already exists

If you get "database already exists" errors:

```bash
mix ecto.drop
mix ecto.create
mix ecto.migrate
```

### Clean everything and start fresh

```bash
docker-compose down -v
docker-compose up -d
mix ecto.setup
```

## Running Tests

```bash
# Run all tests
mix test

# Run a specific test file
mix test test/jarga_web/components/core_components_test.exs

# Run with detailed output
mix test --trace

# Run tests matching a pattern
mix test --only describe:"button/1"
```
