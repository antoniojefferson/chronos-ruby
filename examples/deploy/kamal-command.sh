#!/usr/bin/env sh
set -eu

# Execute after Kamal publishes the new application version. The variables are
# passed explicitly so the Chronos gem itself never scans the process environment.
kamal app exec --reuse "bundle exec ruby examples/deploy/notify.rb"
