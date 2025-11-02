# Deployment Setup Guide

This guide covers how to set up deployment access to Dress to Impress from a new machine.

## Overview

The deployment system uses Ansible playbooks to automate deployment to `impress.openneo.net`. You'll need:
- SSH key authorized on the production server
- Secret files for configuration and credentials
- Ansible and build dependencies installed locally

## Deploying from Devcontainer

The devcontainer is configured to forward your host's SSH agent, allowing you to deploy without copying keys into the container.

**Setup for Deployers:**

If you have deploy access to the production server, the devcontainer is pre-configured to work automatically:

1. The `IMPRESS_DEPLOY_USER` environment variable is automatically set from your host's `$USER` environment variable
2. On container creation, this creates `~/.ssh/config` inside the container with your username
3. Verify SSH access: `ssh impress.openneo.net whoami` should return your username

Then rebuild the devcontainer.

**For Contributors (Non-Deployers):**

If you don't have deploy access, you don't need to do anything. The devcontainer will skip SSH config creation and show a warning, but this won't affect your ability to develop.

## Setup Checklist for New Machine

If you have an existing machine with deploy access, this workflow lets you bootstrap a new machine by authorizing its SSH key and copying secret files.

### Phase 1: On New Machine

**Prerequisites to Install:** (or use devcontainer)
- [ ] Install Ansible
- [ ] Install Ruby 3.4+
- [ ] Install Node.js/Yarn

**Generate SSH Key:**
- [ ] Generate new SSH key pair: `ssh-keygen -t ed25519 -f ~/.ssh/id_impress_deploy`
- [ ] Copy the **public key** (`~/.ssh/id_impress_deploy.pub`) to a location accessible from your existing machine
  - Example: USB drive, shared network location, or transfer via secure method

### Phase 2: On Existing Machine (Has Deploy Access)

**Add New SSH Key:**
- [ ] Copy the public key from the transfer location to the repository
- [ ] Append public key to `deploy/files/authorized-ssh-keys.txt`
- [ ] Run `bin/deploy:setup` to sync the updated authorized keys to the server
- [ ] Test that the new key works: `ssh -i /path/to/new/private/key impress.openneo.net`

**Copy Secret Files to Transfer Location:**
- [ ] Copy `deploy/files/production.env` to transfer location
- [ ] Copy `deploy/files/setup_secrets.yml` to transfer location (optional, only needed for full setup)

### Phase 3: Return to New Machine

**Copy Secret Files:**
- [ ] Copy `production.env` from transfer location to `deploy/files/production.env`
- [ ] Copy `setup_secrets.yml` from transfer location to `deploy/files/setup_secrets.yml` (optional)
- [ ] `ln -s deploy/files/production.env .env.production`
- [ ] Set proper permissions: `chmod 600` on all secret files

**Configure SSH:**
- [ ] Ensure SSH key has proper permissions: `chmod 600 ~/.ssh/id_impress_deploy`
- [ ] (Optional) Add to `~/.ssh/config`:
  ```
  Host impress.openneo.net
      IdentityFile ~/.ssh/id_impress_deploy
  ```

**Verify Access:**
- [ ] Test SSH connection: `ssh impress.openneo.net`
- [ ] Verify deployment works: `bin/deploy`

### Security Reminder
- [ ] Delete secret files from transfer location after copying
- [ ] Optionally remove the temporary public key file from the existing machine

---

## Secret Files Reference

These files are gitignored and must be obtained from an existing deployment machine or production server:

### 1. `deploy/files/production.env`
Production environment variables deployed to `/srv/impress/shared/production.env` on the server.

Required variables:
- `DATABASE_URL_PRIMARY` - MySQL connection URL for primary database
- `DATABASE_URL_OPENNEO_ID` - MySQL connection URL for auth database
- `IMPRESS_2020_ORIGIN` - URL of Impress 2020 service (optional, defaults to `https://impress-2020.openneo.net`)
- `RAILS_LOG_LEVEL` - Log level (optional, defaults to "info")

### 2. `deploy/files/setup_secrets.yml`
Ansible variables for the setup playbook. Only needed if running initial server setup (`bin/deploy:setup`).

Required variables:
- `mysql_root_password` - Root password for MySQL/MariaDB
- `mysql_user_password` - Password for `openneo_impress` MySQL user
- `mysql_user_password_2020` - Password for `impress2020` MySQL user
- `dev_ips` - List of IP addresses allowed to connect to MySQL

Decrypts credentials including:
- `matchu_email_password` - SMTP password for `matchu@openneo.net` (Fastmail)
- `neopass.client_secret` - OAuth client secret for NeoPass integration

## Deployment Commands

### Initial Server Setup (one-time)
```bash
bin/deploy:setup
```
Runs the Ansible setup playbook to configure the server (Ruby, MySQL, nginx, SSL, users, firewall, etc.). Prompts for sudo password.

### Deploy New Version
```bash
bin/deploy
```
Compiles assets locally, then deploys to production. No sudo required.

### Rollback
```bash
bin/deploy:rollback [version-name]
```
Rolls back to a previous deployment.

## Server Details

- **Host:** `impress.openneo.net`
- **OS:** Ubuntu 20.04 LTS
- **Ruby:** 3.4.5
- **App location:** `/srv/impress/`
- **Deploy user:** `impress`
- **Service:** systemd service named `impress`

## Troubleshooting

**SSH Permission Denied:**
- Verify your SSH key is in `authorized-ssh-keys.txt` and `bin/deploy:setup` was run
- Check key permissions: `chmod 600 ~/.ssh/id_impress_deploy`
- Test with verbose output: `ssh -v impress.openneo.net`

**Asset Compilation Fails:**
- Ensure Ruby and Node.js/Yarn are installed

**Deployment Permission Errors:**
- Verify your user is in the `impress-deployers` group on the server
- This is set up automatically by `bin/deploy:setup`
