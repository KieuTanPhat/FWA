import './config';
import { readFileSync } from 'fs';
import { resolve } from 'path';
import { Pool } from 'pg';

async function main() {
  const db = new Pool({ connectionString: process.env.DATABASE_URL });
  try {
    await db.query(readFileSync(resolve(__dirname, '../sql/001_init.sql'), 'utf8'));
    process.stdout.write('Migration hoàn tất\n');
  } finally { await db.end(); }
}
void main();
