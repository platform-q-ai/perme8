# Deployment Guide - Render.com

This guide covers deploying the Jarga Phoenix application to Render.com.

## Prerequisites

- A [Render.com](https://render.com) account
- Your repository pushed to GitHub/GitLab/Bitbucket
- PostgreSQL database (will be created on Render)

## Overview

The application is configured for deployment using Elixir releases on Render.com. The deployment process:

1. Runs `build.sh` to compile and build assets
2. Creates a production release
3. Runs migrations on first deploy or updates
4. Starts the Phoenix server

## Step 1: Create a PostgreSQL Database

1. Go to your [Render Dashboard](https://dashboard.render.com)
2. Click **New** → **PostgreSQL**
3. Configure the database:
   - **Name**: `jarga-db` (or your preferred name)
   - **Database**: `jarga` (this database will be created automatically by Render)
   - **User**: (auto-generated)
   - **Region**: Choose closest to your users
   - **Plan**: Free tier for testing, paid for production
4. Click **Create Database**
5. Wait for the database to be provisioned (this creates the database)
6. Note the **Internal Database URL** (starts with `postgresql://`)

> **Important**: Render automatically creates the database when provisioning PostgreSQL. The Pre-Deploy Command will then create the schema (tables) and run migrations.

## Step 2: Create a Web Service

1. In Render Dashboard, click **New** → **Web Service**
2. Connect your repository
3. Configure the service:

### Basic Configuration

- **Name**: `jarga` (or your preferred name)
- **Region**: Same as your database
- **Branch**: `main` (or your production branch)
- **Runtime**: **Elixir**

### Build & Deploy

- **Build Command**: `./build.sh`
- **Pre-Deploy Command**: `_build/prod/rel/jarga/bin/migrate`
- **Start Command**: `_build/prod/rel/jarga/bin/server`

> **Note**: The Pre-Deploy Command automatically creates the database schema and runs all migrations before each deployment. This ensures your database is always up to date.

### Instance Type

- **Free** for testing
- **Starter** or higher for production (recommended for databases)

## Step 3: Configure Environment Variables

Add these environment variables in the Render dashboard (Environment tab):

### Required Variables

| Variable | Description | How to Generate |
|----------|-------------|-----------------|
| `DATABASE_URL` | PostgreSQL connection string | Use the **Internal Database URL** from Step 1 |
| `SECRET_KEY_BASE` | Secret key for encryption/signing | Run `mix phx.gen.secret` locally |
| `PHX_SERVER` | Enable Phoenix server | Set to `true` |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `POOL_SIZE` | `10` | Database connection pool size |
| `PORT` | `4000` | Port the app listens on (Render sets this automatically) |
| `RENDER_EXTERNAL_HOSTNAME` | Auto-set by Render | Your app's hostname (set automatically) |

### Example Environment Variables

```bash
DATABASE_URL=postgresql://user:password@dpg-xxxxx-a.oregon-postgres.render.com/jarga
SECRET_KEY_BASE=your_generated_secret_key_here_use_mix_phx_gen_secret
PHX_SERVER=true
POOL_SIZE=10
```

## Step 4: Deploy

1. Click **Create Web Service**
2. Render will automatically:
   - Clone your repository
   - Run the build script
   - Run database migrations (via `rel/overlays/bin/migrate`)
   - Start your application
3. Monitor the logs for any errors
4. Once deployed, visit your app at `https://your-app-name.onrender.com`

## Automatic Deployment via GitHub Actions

The repository includes a GitHub Actions workflow that automatically deploys to Render when code is pushed to the `main` branch after all tests pass.

### Setup Automatic Deployment

1. **Get your Render Deploy Hook URL**:
   - Go to your web service in Render Dashboard
   - Navigate to **Settings** → **Deploy Hook**
   - Copy the deploy hook URL (looks like `https://api.render.com/deploy/srv-xxxxx...`)
   - **Keep this URL secret!** It allows anyone to trigger deployments

2. **Add the Deploy Hook to GitHub Secrets**:
   - Go to your GitHub repository
   - Click **Settings** → **Secrets and variables** → **Actions**
   - Click **New repository secret**
   - Name: `RENDER_DEPLOY_HOOK_URL`
   - Value: Paste your Render deploy hook URL
   - Click **Add secret**

3. **How it Works**:
   - On every push to `main`, GitHub Actions runs:
     1. Compile the application
     2. Run Credo code quality checks
     3. Run Elixir tests
     4. Run JavaScript tests
   - If all tests pass, it triggers a deployment to Render
   - Pull requests run tests but do NOT deploy

### Deployment Workflow

```
Push to main → Tests run → Tests pass → Deploy triggered → Render builds → Deploy live
                   ↓
              Tests fail → No deployment
```

### Manual Deployment

You can also trigger deployments manually in Render:

1. Go to your web service in Render Dashboard
2. Click **Manual Deploy** → **Deploy latest commit**
3. Or push any commit to the `main` branch to trigger automatic deployment

### Monitoring Deployments

- **GitHub Actions**: View deployment status in the **Actions** tab of your repository
- **Render Dashboard**: View build logs and deployment status in your service's **Events** tab

## Database Migrations

Migrations run automatically on each deploy via the Pre-Deploy Command configured in Step 2 (`_build/prod/rel/jarga/bin/migrate`). This command:

1. Ensures all required database tables exist
2. Runs any pending migrations
3. Runs before your application starts

### Manual Migration

If you need to run migrations manually:

1. Go to your web service in Render
2. Click **Shell** tab
3. Run: `_build/prod/rel/jarga/bin/migrate`

### Rollback

To rollback to a specific migration version:

```bash
_build/prod/rel/jarga/bin/jarga eval "Jarga.Release.rollback(Jarga.Repo, 20251103145700)"
```

## Custom Domain

To use a custom domain:

1. Go to your web service **Settings**
2. Click **Custom Domains**
3. Add your domain
4. Update your DNS records as instructed
5. The `RENDER_EXTERNAL_HOSTNAME` will automatically update

## Monitoring & Logs

- **Logs**: View real-time logs in the Render dashboard under the **Logs** tab
- **Metrics**: Monitor CPU, memory, and request metrics in the **Metrics** tab
- **Health Checks**: Render automatically monitors your app's health

## Troubleshooting

### Build Fails

- Check that `mix.lock` is committed to your repository
- Ensure all dependencies are compatible with production environment
- Review build logs in Render dashboard

### Database Connection Fails

- Verify `DATABASE_URL` is set correctly (use Internal URL, not External)
- Ensure database and web service are in the same region
- Check that database is running and accessible

### App Won't Start

- Check that `SECRET_KEY_BASE` is set
- Verify `PHX_SERVER=true` is set
- Review start command: `_build/prod/rel/jarga/bin/server`
- Check logs for specific error messages

### SSL/HTTPS Issues

- The app is configured with `force_ssl: [hsts: true]` in production
- Render provides automatic SSL certificates
- All HTTP requests will redirect to HTTPS

## Testing Locally

Before deploying, test the production build locally:

```bash
# Build the release
./build.sh

# Set required environment variables
export DATABASE_URL="postgresql://user:password@localhost/jarga_prod"
export SECRET_KEY_BASE=$(mix phx.gen.secret)
export PHX_SERVER=true

# Run migrations
_build/prod/rel/jarga/bin/migrate

# Start the server
_build/prod/rel/jarga/bin/server
```

Visit http://localhost:4000 to verify everything works.

## Updating the Application

### With GitHub Actions (Recommended)

If you've set up automatic deployment:

1. Create a feature branch and make your changes
2. Push to GitHub and create a pull request
3. GitHub Actions runs all tests on the PR
4. Merge the PR into `main`
5. GitHub Actions automatically deploys to Render after tests pass

### Manual Deployment

Without GitHub Actions:

1. Push changes to your `main` branch
2. Render automatically detects changes and redeploys
3. Migrations run automatically before the new version starts
4. Zero-downtime deployment (on paid plans)

## Production Checklist

Before going live:

- [ ] PostgreSQL database created on Render
- [ ] Web service created and configured
- [ ] Required environment variables set (`DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_SERVER`)
- [ ] GitHub Actions deploy hook configured (optional but recommended)
- [ ] Database backups enabled (automatic on Render paid plans)
- [ ] Custom domain configured
- [ ] Email service configured (Swoosh adapters)
- [ ] Error tracking set up (Sentry, AppSignal, etc.)
- [ ] Health check endpoint working
- [ ] SSL/HTTPS working correctly
- [ ] Database connection pool sized appropriately
- [ ] Monitoring and alerting configured

## Additional Resources

- [Render Phoenix Documentation](https://render.com/docs/deploy-phoenix)
- [Phoenix Deployment Guides](https://hexdocs.pm/phoenix/deployment.html)
- [Elixir Releases](https://hexdocs.pm/mix/Mix.Tasks.Release.html)
- [Render Documentation](https://render.com/docs)

## Support

For issues specific to Render.com deployment, contact [Render Support](https://render.com/support).
