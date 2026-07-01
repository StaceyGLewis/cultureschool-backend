'use strict';

/**
 * POST /api/export-mp4
 * Records an animated board page as MP4 and returns binary video.
 *
 * Body: { board_id: string, duration_seconds?: number (1–30, default 8) }
 *
 * Requires:
 *   - @sparticuz/chromium  (npm pkg — self-extracts to /tmp at runtime)
 *   - puppeteer-core       (npm pkg)
 *   - ffmpeg               (already on Render)
 *
 * Typical response time: ~15-30s. Client should set a 60s timeout.
 * Frontend call: POST https://cultureschool-backend.onrender.com/api/export-mp4
 */

const { exec }  = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);
const fs        = require('fs');
const path      = require('path');
const os        = require('os');
const { v4: uuidv4 } = require('uuid');

const VIEWER_BASE   = 'https://showcase-viewer.cultureschool.org';
const DEFAULT_SECS  = 8;
const MAX_SECS      = 30;
const CAPTURE_FPS   = 12;
const WIDTH         = 1280;
const HEIGHT        = 720;

// ── record the page via CDP screencast → JPEG frames on disk ─────────────────
async function captureFrames(url, durationSecs, framesDir) {
  const puppeteer  = require('puppeteer-core');
  const chromium   = require('@sparticuz/chromium');

  // sparticuz/chromium sets its own recommended args; merge ours in
  const args = [
    ...chromium.args,
    '--disable-web-security',
    '--autoplay-policy=no-user-gesture-required',
    `--window-size=${WIDTH},${HEIGHT}`,
  ];

  const browser = await puppeteer.launch({
    executablePath: await chromium.executablePath(),
    headless:       chromium.headless,
    args,
  });

  let frameIndex = 0;

  try {
    const page = await browser.newPage();
    await page.setViewport({ width: WIDTH, height: HEIGHT });

    const cdp = await page.createCDPSession();

    // Collect JPEG frames from CDP screencast
    cdp.on('Page.screencastFrame', async ({ data, sessionId }) => {
      const framePath = path.join(
        framesDir,
        `frame-${String(frameIndex++).padStart(6, '0')}.jpg`
      );
      fs.writeFileSync(framePath, Buffer.from(data, 'base64'));
      // Ack so Chrome keeps sending frames
      await cdp.send('Page.screencastFrameAck', { sessionId }).catch(() => {});
    });

    await cdp.send('Page.startScreencast', {
      format:          'jpeg',
      quality:         85,
      maxWidth:        WIDTH,
      maxHeight:       HEIGHT,
      everyNthFrame:   1,
    });

    await page.goto(url, { waitUntil: 'networkidle0', timeout: 25000 });

    // Let animations initialise before the clock starts
    await new Promise(r => setTimeout(r, 2000));

    // Actual recording window
    await new Promise(r => setTimeout(r, durationSecs * 1000));

    await cdp.send('Page.stopScreencast');
  } finally {
    await browser.close();
  }

  return frameIndex;
}

// ── stitch JPEG frames → MP4 via ffmpeg (already on Render) ─────────────────
async function encodeMp4(framesDir, outputPath) {
  const cmd = [
    'ffmpeg -y',
    `-framerate ${CAPTURE_FPS}`,
    `-i "${framesDir}/frame-%06d.jpg"`,
    '-c:v libx264',
    '-pix_fmt yuv420p',
    '-preset fast',
    '-crf 22',
    // Pad to even dimensions (required by libx264)
    `-vf "scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,` +
      `pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black"`,
    `"${outputPath}"`,
  ].join(' ');

  await execAsync(cmd, { timeout: 120_000 });
}

// ── Express route ─────────────────────────────────────────────────────────────
module.exports = function mountExportMp4(app) {
  app.post('/api/export-mp4', async (req, res) => {
    const { board_id, duration_seconds } = req.body || {};

    if (!board_id) {
      return res.status(400).json({ success: false, error: 'board_id is required' });
    }

    const duration = Math.min(
      Math.max(1, parseInt(duration_seconds, 10) || DEFAULT_SECS),
      MAX_SECS
    );

    const sessionId  = uuidv4();
    const sessionDir = path.join(os.tmpdir(), 'coco-export', sessionId);
    const framesDir  = path.join(sessionDir, 'frames');
    const outputPath = path.join(sessionDir, 'output.mp4');

    fs.mkdirSync(framesDir, { recursive: true });

    const viewerUrl = `${VIEWER_BASE}/?board_id=${encodeURIComponent(board_id)}`;
    console.log(`[export-mp4] ${viewerUrl}  duration=${duration}s`);

    try {
      const frameCount = await captureFrames(viewerUrl, duration, framesDir);

      if (frameCount === 0) {
        throw new Error('No frames captured — page may not have loaded in time');
      }

      console.log(`[export-mp4] ${frameCount} frames captured, encoding…`);
      await encodeMp4(framesDir, outputPath);

      const stat = fs.statSync(outputPath);
      res.setHeader('Content-Type', 'video/mp4');
      res.setHeader(
        'Content-Disposition',
        `attachment; filename="coco-${board_id}.mp4"`
      );
      res.setHeader('Content-Length', stat.size);

      const stream = fs.createReadStream(outputPath);
      stream.pipe(res);
      stream.on('end', () => cleanup(sessionDir));
      stream.on('error', err => {
        console.error('[export-mp4] stream error:', err.message);
        cleanup(sessionDir);
        if (!res.headersSent) {
          res.status(500).json({ success: false, error: 'Stream failed' });
        }
      });

    } catch (err) {
      console.error('[export-mp4]', err.message);
      cleanup(sessionDir);
      return res.status(500).json({ success: false, error: err.message });
    }
  });
};

function cleanup(dir) {
  try { fs.rmSync(dir, { recursive: true, force: true }); } catch {}
}
