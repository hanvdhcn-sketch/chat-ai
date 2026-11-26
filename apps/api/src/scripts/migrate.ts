import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { closePool, getPool } from '../services/db.js';

/**
 * Applies apps/api/migrations/*.sql in filename order, once each.
 * Usage: DATABASE_URL=... npm run migrate -w @chatai/api
 * (also the Fly.io release command, see docs/deploy-fly.md).
 */
async function main(): Promise<void> {
  const here = path.dirname(fileURLToPath(import.meta.url));
  const dir = path.resolve(here, '..', '..', 'migrations');
  const files = (await readdir(dir)).filter((f) => f.endsWith('.sql')).sort();

  const client = await getPool().connect();
  try {
    // Serialize concurrent deploys.
    await client.query('select pg_advisory_lock(727001)');
    await client.query(`
      create table if not exists public.schema_migrations (
        name text primary key,
        applied_at timestamptz not null default now()
      )`);
    const done = new Set(
      (
        await client.query<{ name: string }>(
          'select name from public.schema_migrations',
        )
      ).rows.map((r) => r.name),
    );

    for (const file of files) {
      if (done.has(file)) {
        console.log(`skip   ${file}`);
        continue;
      }
      const sql = await readFile(path.join(dir, file), 'utf8');
      await client.query('begin');
      try {
        await client.query(sql);
        await client.query(
          'insert into public.schema_migrations (name) values ($1)',
          [file],
        );
        await client.query('commit');
        console.log(`apply  ${file}`);
      } catch (err) {
        await client.query('rollback');
        throw err;
      }
    }
    await client.query('select pg_advisory_unlock(727001)');
  } finally {
    client.release();
    await closePool();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
