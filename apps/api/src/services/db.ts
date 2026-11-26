import pg from 'pg';
import { config, isDatabaseConfigured } from '../config.js';

export type SqlClient = {
  query: <R extends pg.QueryResultRow = pg.QueryResultRow>(
    text: string,
    values?: unknown[],
  ) => Promise<{ rows: R[]; rowCount: number | null }>;
};

let pool: pg.Pool | null = null;

/** Lazily-created pool for the Supabase Postgres connection string. */
export function getPool(): pg.Pool {
  if (!isDatabaseConfigured()) {
    throw new Error('DATABASE_URL is not set');
  }
  if (!pool) {
    pool = new pg.Pool({
      connectionString: config.databaseUrl,
      max: 5,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 10_000,
      // Supabase pooler certificates are not in the default trust store.
      ssl:
        config.databaseSsl === 'disable'
          ? false
          : { rejectUnauthorized: false },
    });
  }
  return pool;
}

export async function pingDatabase(): Promise<boolean> {
  if (!isDatabaseConfigured()) return false;
  try {
    await getPool().query('select 1');
    return true;
  } catch {
    return false;
  }
}

export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
}
