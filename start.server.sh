#!/bin/bash

echo "📦 Auto-saving Git changes..."
git add .
git commit -m "🔄 Auto-commit on $(date '+%Y-%m-%d %H:%M:%S')"
git push origin main

echo "🔁 Restarting CultureSchool server..."

# Stop old PM2 process
pm2 delete cultureschool || echo "🟡 No existing 'cultureschool' process found"

# Start and name new one
pm2 start server.js --name cultureschool

# Save for reboot
pm2 save

# Ensure PM2 auto-starts on reboot
pm2 startup | tail -n 1 | bash

echo "✅ CultureSchool server running under PM2 on port 5055 and latest Git changes pushed!"
