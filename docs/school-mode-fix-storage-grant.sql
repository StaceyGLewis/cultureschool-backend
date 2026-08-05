-- ═══════════════════════════════════════════════════════════════════════
-- FIX — teachers cannot open any class-works image
--
-- Apply this now. It is two lines and reversible.
--
-- ── The bug ────────────────────────────────────────────────────────────
-- school-mode-storage.sql revoked EXECUTE on _school_owns_object from
-- authenticated:
--
--   revoke all on function public._school_owns_object(text)
--     from public, anon, authenticated;
--
-- That was wrong. The storage policy CALLS that function, and a policy is
-- evaluated as the calling role. With EXECUTE revoked, every read of a
-- class-works object fails with:
--
--   permission denied for function _school_owns_object
--
-- Supabase surfaces that as a 400 from createSignedUrl, and the client
-- treats a missing URL as "no image", so it fails silently — an empty grey
-- box where a photograph should be. It was reported as a note-photo bug;
-- it actually breaks every image a teacher tries to open, prints included.
--
-- ── Why granting it is still safe ──────────────────────────────────────
-- The function is SECURITY DEFINER and takes only a path. It reads the
-- caller's identity from auth.jwt() itself and answers one question: does
-- the class in this path belong to you? Being able to call it tells you
-- nothing you could not already work out by trying to read the object.
-- The secrecy was never doing any work; it was only breaking the policy.
-- ═══════════════════════════════════════════════════════════════════════

begin;

grant execute on function public._school_owns_object(text) to authenticated;

-- anon stays revoked: a student is anonymous and reads their own files
-- through the school-upload function, never through this policy.
revoke execute on function public._school_owns_object(text) from anon;

commit;

-- ═══════════════════════════════════════════════════════════════════════
-- VERIFY
--   select has_function_privilege('authenticated',
--            'public._school_owns_object(text)', 'execute');   -- must be true
--   select has_function_privilege('anon',
--            'public._school_owns_object(text)', 'execute');   -- must be false
--
-- Then, signed in as a teacher, open any submitted work: the print and any
-- source photographs should both render.
-- ═══════════════════════════════════════════════════════════════════════
