reorg_micro_gallery.sh

# Define target folder
TARGET="micro-gallery-app"

# Create new folder
mkdir -p $TARGET

# Move frontend files into new app directory
mv App.jsx $TARGET/
mv App.css $TARGET/ 2>/dev/null
mv index.css $TARGET/ 2>/dev/null
mv index.js $TARGET/
mv PinCard.jsx $TARGET/
mv ProfileHeader.js $TARGET/
mv public $TARGET/public
mv .env $TARGET/.env 2>/dev/null

# Move microgallery server into app folder
mv microgallery.server.js $TARGET/server.js

# Optional: move package files if they're not shared with the main backend
mv package.json $TARGET/package.json
mv package-lock.json $TARGET/package-lock.json

echo "✅ Reorganization complete. Your micro-gallery app is now in: $TARGET/"
