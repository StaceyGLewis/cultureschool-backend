#!/usr/bin/env bash
set -e

# Install Chromium for page recording (export-mp4 route)
# ffmpeg is already present in the Render environment
apt-get update -qq
apt-get install -y --no-install-recommends chromium

npm ci
