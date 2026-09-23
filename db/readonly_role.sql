-- ===========================================================================
-- Read-only database role for the application runtime.
--
-- WHY THIS FILE EXISTS
-- The single most important security control in a text-to-SQL system is NOT
-- prompt engineering. It is the database permission model.
--
-- No matter how good your prompt is, a language model can be talked into
-- emitting "DROP TABLE customers". Prompt-level defences are probabilistic.
-- A Postgres role that lacks DELETE, UPDATE, INSERT and DROP privileges is
-- deterministic - the database refuses, every time, regardless of what the
-- model produced or what the user typed.
--
-- Defence in depth for this project, outermost first:
--   1. This read-only role                 <- the one that cannot be bypassed
--   2. statement_timeout on the role       <- stops runaway queries
--   3. SQL parsing + allowlist (sqlglot)   <- rejects non-SELECT before execute
--   4. Row limit injected into every query <- bounds result size
--   5. Prompt instructions                 <- weakest layer, but still useful
--
-- Run this ONCE as a superuser (or the database owner) after schema.sql.
-- Replace the password with a strong value and store it in .env as
-- DATABASE_URL_READONLY.
-- ===========================================================================

-- 1. Create the role. LOGIN lets it connect; it owns nothing.
DROP ROLE IF EXISTS t2s_readonly;
CREATE ROLE t2s_readonly WITH LOGIN PASSWORD 'CHANGE_ME_STRONG_PASSWORD';

-- 2. Let it connect to the database and see the public schema, nothing more.
GRANT CONNECT ON DATABASE current_database_placeholder TO t2s_readonly;
GRANT USAGE   ON SCHEMA public TO t2s_readonly;

-- 3. SELECT on existing tables. Note: SELECT only. No INSERT/UPDATE/DELETE.
GRANT SELECT ON ALL TABLES IN SCHEMA public TO t2s_readonly;

-- 4. And on any table created later, so a new table does not silently become
--    invisible to the app and force someone to re-grant in a hurry.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO t2s_readonly;

-- 5. Explicitly remove the ability to create anything in the schema.
REVOKE CREATE ON SCHEMA public FROM t2s_readonly;

-- 6. Kill any query this role runs that exceeds 10 seconds. A model can
--    easily generate an accidental cross join over millions of rows; this
--    turns a potential outage into a single failed request.
ALTER ROLE t2s_readonly SET statement_timeout = '10s';

-- 7. Prevent long-lived idle transactions holding locks.
ALTER ROLE t2s_readonly SET idle_in_transaction_session_timeout = '30s';

-- ---------------------------------------------------------------------------
-- VERIFY IT WORKED. Connect as t2s_readonly and run these. The SELECT must
-- succeed and every write must fail with "permission denied".
--
--   SELECT count(*) FROM customers;          -- expect: a number
--   DELETE FROM customers;                   -- expect: ERROR permission denied
--   UPDATE customers SET email = 'x';        -- expect: ERROR permission denied
--   INSERT INTO customers DEFAULT VALUES;    -- expect: ERROR permission denied
--   DROP TABLE customers;                    -- expect: ERROR must be owner
--   CREATE TABLE evil (id int);              -- expect: ERROR permission denied
--
-- There is a test that asserts exactly this: tests/test_readonly_role.py
-- Running that test in CI is what turns a claim into evidence.
-- ---------------------------------------------------------------------------
