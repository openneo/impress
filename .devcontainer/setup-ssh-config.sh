#!/bin/bash
# Creates SSH config for devcontainer to use host's SSH identity
# This allows `ssh impress.openneo.net` to work without hardcoding usernames

mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Only create SSH config if IMPRESS_DEPLOY_USER is explicitly set
if [ -z "$IMPRESS_DEPLOY_USER" ]; then
  echo "⚠️  IMPRESS_DEPLOY_USER not set - skipping SSH config creation."
  echo "   This should be automatically set from your host \$USER environment variable."
  echo "   See docs/deployment-setup.md for details."
  exit 0
fi

cat > ~/.ssh/config <<EOF
# Deployment server config
# Username: ${IMPRESS_DEPLOY_USER}
Host impress.openneo.net
  User ${IMPRESS_DEPLOY_USER}
  ForwardAgent yes

# Add other host configurations as needed
EOF

chmod 600 ~/.ssh/config

echo "✓ SSH config created. Deployment username: ${IMPRESS_DEPLOY_USER}"
