import test from 'node:test';
import assert from 'node:assert/strict';
import { createHandler } from '../supabase/functions/delete-account/handler.mjs';
const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
function setup(failure) {
  const calls = [];
  const handler = createHandler({url: 'https://test.invalid', anonKey: 'anon', serviceKey: 'secret',
    fetcher: async (url, options) => {
      const path = new URL(url).pathname; calls.push({path, ...options});
      if (path.includes(failure || 'never-matches')) return new Response(JSON.stringify({code:'P0001',message:'Viaje activo'}), {status:409});
      const body = path === '/auth/v1/user' ? {id} : path.endsWith('account_deletion_objects')
        ? [{bucket_id:'driver-documents',name:`${id}/license.pdf`}] : {};
      return new Response(JSON.stringify(body));
    }});
  return {handler,calls};
}
const request = () => new Request('https://test.invalid/delete-account', {method:'POST', headers:{Authorization:'Bearer session'}, body:JSON.stringify({user_id:'someone-else'})});
test('missing authentication causes no backend access', async()=>{
  const {handler,calls}=setup(); const result=await handler(new Request('https://test.invalid', {method:'POST'}));
  assert.equal(result.status,401); assert.equal(calls.length,0);
});
test('server identity selects target; storage precedes data then Auth', async()=>{
  const {handler,calls}=setup(); assert.equal((await handler(request())).status,200);
  assert.deepEqual(calls.map(x=>x.path), ['/auth/v1/user','/rest/v1/rpc/request_my_account_deletion','/rest/v1/rpc/account_deletion_objects','/storage/v1/object/driver-documents','/rest/v1/rpc/finish_account_data_deletion',`/auth/v1/admin/users/${id}`]);
  assert.equal(calls[1].headers.Authorization,'Bearer session');
  assert.equal(JSON.parse(calls[2].body).p_user_id,id);
});
for (const failure of ['request_my_account_deletion','account_deletion_objects','/storage/v1/object/','finish_account_data_deletion']) {
  test(`failure at ${failure} never deletes Auth`,async()=>{
    const {handler,calls}=setup(failure); const result=await handler(request());
    assert.notEqual(result.status,200);
    assert.equal(calls.some(x=>x.path.includes('/auth/v1/admin/users/')),false);
  });
}
