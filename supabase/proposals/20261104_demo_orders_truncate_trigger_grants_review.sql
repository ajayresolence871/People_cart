-- REVIEW-ONLY PROPOSAL. Do not apply until the live ACL source and any
-- non-Flutter database/API workflows have been checked and this change is
-- explicitly approved.
--
-- The checked-in Flutter app reads order rows but performs order writes through
-- SECURITY DEFINER RPCs. It does not truncate orders or create triggers. The
-- production SQL Editor results supplied for review show TRUNCATE and TRIGGER
-- privileges for anon and authenticated. RLS does not restrict TRUNCATE, and
-- TRIGGER is not required for existing triggers to fire during DML.
--
-- Keep this separate from the admin status-transition proposal. This removes
-- only these two table privileges for the two client roles. It preserves
-- SELECT, INSERT, UPDATE, DELETE, all RLS policies, function grants, and
-- service_role privileges. Do not apply if an independently verified workflow
-- relies on either privilege for anon or authenticated.
--
-- Preflight: confirm the grants are direct to these roles (not inherited from
-- PUBLIC or another role), confirm no required external workflow depends on
-- them, and save the complete table ACL as the rollback baseline. This REVOKE
-- cannot remove a privilege still inherited through another grant path.

BEGIN;

REVOKE TRUNCATE, TRIGGER
  ON TABLE public.orders
  FROM anon, authenticated;

COMMIT;

-- ROLLBACK NOTES (manual): restore only privileges confirmed in the captured
-- target-environment ACL baseline. Regranting TRUNCATE or TRIGGER reopens the
-- corresponding capability, so do not use a guessed GRANT as an automatic
-- rollback.
