#!/usr/bin/env bash
set -e # Quit if any part of this script fails.

# Mark all git repositories as safe to execute, including cached gems.
# NOTE: This would be dangerous to run on a normal multi-user machine,
# but for a dev container that only we use, it should be fine!
git config --global safe.directory '*'

# Install the app's Ruby gem dependencies.
bundle install

# Set up the databases: create the schema, and load in some default data.
rake db:schema:load db:seed
