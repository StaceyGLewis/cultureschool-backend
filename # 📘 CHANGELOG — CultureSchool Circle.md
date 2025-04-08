# 📘 CHANGELOG — CultureSchool Circle
_Last updated: 2025-04-08_

---

## ✨ Updates
### ✅ April 8, 2025

#### 🔄 Core Functional Fixes
- **Fixed renderMessage() replies logic**  
  - Replies now reliably render under their parent messages.
  - Added fallback safety if the `replies` container is invalid or missing.
  - Prevents crashes or blank threads when a reply is malformed.

- **WebSocket & Local Sync Improved**
  - Ensured messages from CoCo and users persist correctly across reloads.
  - Enhanced fallback for polling to reduce missed messages.

---

#### 🧭 UI + Layout Adjustments
- **"🔒 Leave Circle" Button**  
  - Now properly visible and styled across devices.
  - Positioned fixed to the **bottom right** on all screens.

- **Pinned Panel Placement**
  - Fixed issue where pinned messages shifted below main content on larger screens.
  - Now stays **locked in sidebar** on desktop and **top bar** on mobile.

---

#### 🛠 Admin Tools
- Verified:
  - CoCo message posting
  - Manual tribe seeding
  - Circle purge actions

---

## 📌 Notes
- All changes tested on mobile + desktop.
- Changelog added for internal tracking and future updates.
- Let CoCo announce big future changes inside the Circle? 💬

---

## 🧪 Next Up
- Seed more real users into Circle.
- Style onboarding with CoCo across all screens.
- Continue refining pinned content behavior.

