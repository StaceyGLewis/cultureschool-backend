#!/usr/bin/env bash
set -e

# @sparticuz/chromium ships Chromium as an npm package that extracts to /tmp
# at runtime — no system-level apt-get needed.
npm ci
