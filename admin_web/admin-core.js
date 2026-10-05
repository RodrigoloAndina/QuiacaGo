(function (root, factory) {
  const core = factory();
  if (typeof module === 'object' && module.exports) module.exports = core;
  else root.AdminCore = core;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  const zone = 'America/Argentina/Buenos_Aires';
  const tripLabels = { requested: 'Buscando conductor', accepted: 'Aceptado', arrived: 'En origen', in_progress: 'En viaje', awaiting_finish_code: 'Confirmando llegada', payment_pending: 'Esperando pago', completed: 'Finalizado', cancelled: 'Cancelado' };
  const paymentLabels = { pending: 'Pendiente', paid: 'Cobrado', disputed: 'En revisión por soporte', unpaid: 'Sin pagar', waived: 'Deuda anulada' };
  function escape(value) { return String(value ?? '').replace(/[&<>'"]/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[char]); }
  function formatDate(value) {
    const date = new Date(value);
    return !value || Number.isNaN(date.getTime()) ? '—' : new Intl.DateTimeFormat('es-AR', { timeZone: zone, dateStyle: 'short', timeStyle: 'short' }).format(date);
  }
  function paymentLabel(trip) {
    // A cancelled service is never a cash collection, even with stale payment data.
    if (trip.status === 'cancelled') return 'No corresponde';
    return paymentLabels[trip.payment_status] || 'Sin confirmar';
  }
  function csvCell(value) {
    let text = String(value ?? '');
    // Neutralize spreadsheet formulas in user-controlled names and contact fields.
    if (/^[\s\u0000-\u001f]*[=+@-]/.test(text)) text = "'" + text;
    return '"' + text.replaceAll('"', '""') + '"';
  }
  function searchFilter(value) {
    return String(value || '').trim().replace(/[%*(),.\\"']/g, ' ').replace(/\s+/g, ' ').slice(0, 100);
  }
  function pageInfo(index, rows, size) {
    return { previous: index > 0, next: rows.length > size, rows: rows.slice(0, size), label: `Página ${index + 1} · hasta ${size} registros` };
  }
  return Object.freeze({ zone, tripLabels, paymentLabels, escape, formatDate, paymentLabel, csvCell, searchFilter, pageInfo });
});
