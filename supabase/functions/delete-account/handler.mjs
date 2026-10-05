// No client supplied user ID is accepted. The authenticated session selects
// the target; service credentials are confined to the server.
export function createHandler({ url, anonKey, serviceKey, fetcher = fetch }) {
  const headers = { 'Content-Type': 'application/json', 'Cache-Control': 'no-store',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
    'Access-Control-Allow-Methods': 'POST, OPTIONS' };
  const reply = (status, data) => new Response(JSON.stringify(data), { status, headers });
  return async (request) => {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers });
    if (request.method !== 'POST') return reply(405, { error: 'Método no permitido' });
    if (!url || !anonKey || !serviceKey) return reply(503, { error: 'El servicio de eliminación no está configurado.' });
    const authorization = request.headers.get('Authorization') || '';
    if (!authorization.startsWith('Bearer ')) return reply(401, { error: 'Volvé a iniciar sesión.' });
    const call = async (path, method, body, admin = false) => {
      const key = admin ? serviceKey : anonKey;
      const res = await fetcher(`${url}${path}`, { method,
        headers: { apikey: key, Authorization: admin ? `Bearer ${serviceKey}` : authorization, 'Content-Type': 'application/json' },
        body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(20000) });
      const text = await res.text();
      let data; try { data = text ? JSON.parse(text) : null; } catch { data = null; }
      return { ok: res.ok, data };
    };
    try {
      const identity = await call('/auth/v1/user', 'GET');
      const id = identity.data?.id;
      if (!identity.ok || typeof id !== 'string' || !/^[0-9a-f-]{36}$/i.test(id)) return reply(401, { error: 'Volvé a iniciar sesión.' });
      const reserve = await call('/rest/v1/rpc/request_my_account_deletion', 'POST', {});
      if (!reserve.ok) {
        const message = reserve.data?.code === 'P0001' ? reserve.data.message : 'No se pudo iniciar la eliminación. Contactá a soporte.';
        return reply(409, { error: message });
      }
      const objects = await call('/rest/v1/rpc/account_deletion_objects', 'POST', { p_user_id: id }, true);
      if (!objects.ok || !Array.isArray(objects.data)) throw new Error('object-list');
      const buckets = new Map();
      for (const object of objects.data) {
        if (typeof object.bucket_id !== 'string' || typeof object.name !== 'string') throw new Error('object-shape');
        if (!buckets.has(object.bucket_id)) buckets.set(object.bucket_id, []);
        buckets.get(object.bucket_id).push(object.name);
      }
      for (const [bucket, names] of buckets) {
        for (let i = 0; i < names.length; i += 100) {
          const removed = await call(`/storage/v1/object/${encodeURIComponent(bucket)}`, 'DELETE', { prefixes: names.slice(i, i + 100) }, true);
          if (!removed.ok) throw new Error('storage');
        }
      }
      const cleaned = await call('/rest/v1/rpc/finish_account_data_deletion', 'POST', { p_user_id: id }, true);
      if (!cleaned.ok) throw new Error('data-cleanup');
      const deleted = await call(`/auth/v1/admin/users/${id}`, 'DELETE', { should_soft_delete: false }, true);
      if (!deleted.ok) throw new Error('auth-cleanup');
      return reply(200, { success: true });
    } catch (_) {
      return reply(503, { error: 'No se completó la eliminación. Reintentá; los pasos completados no se duplican. Si persiste, contactá a soporte.' });
    }
  };
}
