-- Make user_settings (user_id, key) unique. Previously the table had
-- no unique constraint, which let two rows for the same (user, key) pair
-- coexist silently. Combined with a `find_all` query that did not filter
-- by user_id, this let one user's settings leak into another's GET
-- response and let PATCH /api/setting silently create duplicate rows
-- when called by more than one user.
--
-- This migration:
--   1. Deduplicates existing rows by keeping the most-recently-updated row
--      per (user_id, key) pair.
--   2. Adds a UNIQUE constraint on (user_id, key) so future writes can't
--      create a collision.
ALTER TABLE user_settings
    ADD CONSTRAINT user_settings_user_id_key_unique UNIQUE (user_id, key);
