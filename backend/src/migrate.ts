import './config';
import { readdirSync, readFileSync } from 'fs';
import { resolve } from 'path';
import { Pool } from 'pg';

async function main() {
  const db = new Pool({ connectionString: process.env.DATABASE_URL });
  try {
    const sqlDir = resolve(__dirname, '../sql');
    const files = readdirSync(sqlDir).filter(f => f.endsWith('.sql')).sort();
    for (const file of files) {
      await db.query(readFileSync(resolve(sqlDir, file), 'utf8'));
      process.stdout.write(`Đã chạy migration: ${file}\n`);
    }
    process.stdout.write('Migration hoàn tất\n');
  } finally { await db.end(); }
}
void main();
