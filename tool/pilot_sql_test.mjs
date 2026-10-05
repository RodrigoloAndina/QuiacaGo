import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
// Isolated, in-memory PostgreSQL. This never connects to the remote project.
const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const db = new PGlite();
await db.exec(`
create role anon; create role authenticated;
create schema auth;
create function auth.uid() returns uuid language sql as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create table profiles(id uuid primary key, enabled boolean, operational boolean, consent boolean);
create table driver_locations(driver_id text, is_online boolean, updated_at timestamptz);
create table trips(passenger_id uuid not null, driver_id text, status text);
create function account_is_enabled(x uuid) returns boolean language sql as $$select enabled from profiles where id=x$$;
create function driver_is_operational(x uuid) returns boolean language sql as $$select operational from profiles where id=x$$;
create function has_current_legal_consent(x uuid) returns boolean language sql as $$select consent from profiles where id=x$$;
`);
const migration = await readFile(new URL('../supabase/pilot_integration.sql', import.meta.url),'utf8');
await db.exec(migration);
await db.exec(migration); // idempotency
const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
await db.query(`insert into profiles values ($1,true,true,true)`,[id]);
await db.query(`insert into driver_locations values ($1,true,now())`,[id]);
const count=async()=>Number((await db.query('select available_driver_count() n')).rows[0].n);
assert.equal(await count(),0,'anonymous caller');
await db.query(`select set_config('request.jwt.claim.sub',$1,false)`,[id]);
assert.equal(await count(),1,'eligible driver');
await db.exec(`update driver_locations set updated_at=now()-interval '46 seconds'`);
assert.equal(await count(),0,'stale GPS');
await db.exec('update driver_locations set updated_at=now()');
await db.query(`insert into trips values (null,$1,'accepted')`,[id]);
assert.equal(await count(),0,'busy driver');
await db.exec(`update trips set status='completed'`);
assert.equal(await count(),1);
for (const column of ['enabled','operational','consent']) {
  await db.exec(`update profiles set ${column}=false`);
  assert.equal(await count(),0,column);
  await db.exec(`update profiles set ${column}=true`);
}
await db.close();
console.log('PASS: migration repeats safely; auth, stale GPS, busy, suspension, documents and consent filters.');
