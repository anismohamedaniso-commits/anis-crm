// Google Apps Script example: send newly added sheet rows to CRM.
// Configure these values before use.
const CRM_WEBHOOK_URL = 'https://YOUR_DOMAIN/api/webhooks/google-sheets';
const CRM_API_KEY = 'YOUR_GOOGLE_SHEETS_API_KEY';

function onEdit(e) {
  if (!e || !e.range) return;

  const sheet = e.range.getSheet();
  const rowIndex = e.range.getRow();
  const colIndex = e.range.getColumn();

  // Skip header and only trigger when last column is edited.
  if (rowIndex < 2) return;
  if (colIndex !== sheet.getLastColumn()) return;

  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  const values = sheet.getRange(rowIndex, 1, 1, sheet.getLastColumn()).getValues()[0];

  const row = {};
  for (let i = 0; i < headers.length; i++) {
    const key = String(headers[i] || '').trim();
    if (!key) continue;
    row[key] = values[i];
  }

  // Optional defaults for CRM mapping.
  row.source = row.source || 'imported';
  row.sheet_name = sheet.getName();

  UrlFetchApp.fetch(CRM_WEBHOOK_URL, {
    method: 'post',
    contentType: 'application/json',
    headers: {
      'x-api-key': CRM_API_KEY,
    },
    payload: JSON.stringify({ row: row }),
    muteHttpExceptions: true,
  });
}
