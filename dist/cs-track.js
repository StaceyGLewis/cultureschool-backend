/* ============================================================================
   CultureSchool telemetry  ->  public.cs_events
   Hosted at /cs-track.js — served from the same Netlify deployment.

   event_type CHECK constraint — only these nine values are accepted:
     search, view, download, save, share,
     palette_view, pattern_view, creator_view, museum_view
   entity_id MUST be a UUID or it is dropped to null.
   No `surface` column — surface goes in metadata.
   ============================================================================ */
(function () {
  var URL_ = 'https://qwulthvbwujfehgdegtn.supabase.co';
  var KEY_ = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3dWx0aHZid3VqZmVoZ2RlZ3RuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQyMDcxODIsImV4cCI6MjA1OTc4MzE4Mn0.t9n4eZng6d0jggiPNK-J_DByvEE2L9tqy5Xh_1-TSoQ';

  var ALLOWED = ['search','view','download','save','share',
                 'palette_view','pattern_view','creator_view','museum_view'];

  var UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

  var SID;
  try {
    SID = localStorage.getItem('cs_sid');
    if (!SID) {
      SID = (window.crypto && crypto.randomUUID) ? crypto.randomUUID()
            : 'sid-' + Date.now() + '-' + Math.random().toString(36).slice(2);
      localStorage.setItem('cs_sid', SID);
    }
  } catch (e) { SID = 'nostorage'; }

  var SURFACE = (function () {
    var h = location.hostname;
    if (h.indexOf('patterns-library')   > -1) return 'library';
    if (h.indexOf('pattern-dictionary') > -1) return 'dictionary';
    if (h.indexOf('print-studio')       > -1) return 'generator';
    if (h.indexOf('patch-studio')       > -1) return 'studio';
    if (h.indexOf('color-lab')          > -1) return 'color-lab';
    if (h.indexOf('color-stories')      > -1) return 'color-stories';
    if (h.indexOf('palettes')           > -1) return 'palettes';
    if (h.indexOf('atlas')              > -1) return 'atlas';
    return 'shop';
  })();

  var UID = null;
  try {
    var _sb = window.sb || window.supabase;
    if (_sb && _sb.auth && _sb.auth.getSession) {
      _sb.auth.getSession().then(function (r) {
        UID = (r && r.data && r.data.session) ? r.data.session.user.id : null;
      }).catch(function () {});
    }
  } catch (e) {}

  window.csTrack = function (event_type, o) {
    o = o || {};
    try {
      if (ALLOWED.indexOf(event_type) === -1) {
        console.warn('[csTrack] invalid event_type:', event_type, '— allowed:', ALLOWED.join(', '));
        return;
      }
      var eid = (o.id && UUID_RE.test(String(o.id))) ? String(o.id) : null;
      var meta = o.meta || {};
      meta.surface = o.surface || SURFACE;
      if (o.id && !eid) meta.raw_id = String(o.id);

      fetch(URL_ + '/rest/v1/cs_events', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', apikey: KEY_,
                   Authorization: 'Bearer ' + KEY_, Prefer: 'return=minimal' },
        body: JSON.stringify({
          event_type:   event_type,
          query:        o.query        || null,
          entity_type:  o.type         || null,
          entity_id:    eid,
          entity_slug:  o.slug         || null,
          user_id:      UID,
          session_id:   SID,
          country_code: null,
          referrer:     document.referrer || null,
          metadata:     meta
        }),
        keepalive: true
      }).catch(function () {});
    } catch (e) { /* telemetry must never break the page */ }
  };
})();
