-- =============================================================================
-- 00_bootstrap.sql — AMEXAN role + database
-- -----------------------------------------------------------------------------
-- Run once against the default PostgreSQL database (usually 'postgres') as a
-- superuser. The migration scripts do this automatically.
--
-- Usage:
--   psql -U postgres -h localhost -f database/00_bootstrap.sql
-- =============================================================================

-- The application role -------------------------------------------------------
DO $$
BEGIN
   IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'amexan') THEN
      CREATE ROLE amexan WITH LOGIN PASSWORD 'amexan';
   END IF;
END
$$;

-- The database ---------------------------------------------------------------
SELECT 'CREATE DATABASE amexan OWNER amexan ENCODING ''UTF8'''
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'amexan')\gexec

-- Optional convenience: give the superuser explicit ownership paths ----------
GRANT ALL PRIVILEGES ON DATABASE amexan TO amexan;
