/**
 * Дім євангелія — приймач заявок «Додай свій день народження».
 *
 * Форма на GitHub Pages надсилає сюди дані, а скрипт передає їх у Telegram-групу адміністраторів.
 * Токен бота живе ТІЛЬКИ тут (Script properties) — на сайті його немає.
 * Нічого не потрапляє на екран автоматично: адміністратор переглядає заявку в Telegram і сам вносить у базу.
 *
 * ── Script properties (Налаштування проєкту → Властивості скрипта) ──
 *   BOT_TOKEN    — токен від @BotFather                    (обов'язково)
 *   CHAT_ID      — id групи, напр. -1001234567890           (обов'язково)
 *   TOPIC_ID     — id теми, якщо в групі увімкнені теми     (необов'язково)
 *   ACCESS_CODE  — «кодове слово»; якщо задано, форма має його надіслати (необов'язково)
 */

const LIMITS = {
  PER_HOUR: 20,            // максимум заявок на годину (усього)
  PER_6H: 50,              // максимум заявок за ~6 годин (максимальний термін кешу Google)
  BAD_CODE_PER_HOUR: 10,   // спроб з неправильним кодовим словом на годину
  MAX_PHOTO_BYTES: 2.5 * 1024 * 1024,
  MIN_FILL_MS: 3000        // швидше за 3 с людина форму не заповнить
};

const NAME_RE = /^[\p{L}\p{M}'’ʼ\-. ]{1,40}$/u;

class UserError extends Error {}

function doGet() {
  return ContentService.createTextOutput('OK');
}

function doPost(e) {
  try {
    const d = JSON.parse(e.postData.contents);

    // Пастка для ботів: приховане поле заповнене → вдаємо, що все добре, але нічого не надсилаємо
    if (d.website) return reply_({ ok: true });

    checkCode_(d.code);
    const data = validate_(d);
    checkRate_();
    send_(data);
    return reply_({ ok: true });
  } catch (err) {
    if (err instanceof UserError) return reply_({ ok: false, error: err.message });
    console.error(String(err));
    return reply_({ ok: false, error: 'Помилка сервера. Спробуйте пізніше.' });
  }
}

/* ───────────── Перевірки ───────────── */

function checkCode_(code) {
  const expected = prop_('ACCESS_CODE', true);
  if (!expected) return;
  if (String(code || '').trim().toLowerCase() === String(expected).trim().toLowerCase()) return;
  countBad_();
  throw new UserError('Неправильне кодове слово.');
}

function validate_(d) {
  const clean = (s, max) => String(s == null ? '' : s).replace(/[\u0000-\u001F\u007F]/g, ' ').trim().slice(0, max);

  const type = d.type === 'update' ? 'update' : 'new';
  const lastName = clean(d.lastName, 40), firstName = clean(d.firstName, 40), patronymic = clean(d.patronymic, 40);
  if (!NAME_RE.test(lastName)) throw new UserError('Вкажіть прізвище (літери).');
  if (!NAME_RE.test(firstName)) throw new UserError('Вкажіть ім’я (літери).');
  if (patronymic && !NAME_RE.test(patronymic)) throw new UserError('По батькові: лише літери.');

  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(d.birthdate || ''));
  if (!m) throw new UserError('Вкажіть правильну дату народження.');
  const y = +m[1], mo = +m[2], da = +m[3];
  const dt = new Date(Date.UTC(y, mo - 1, da));
  if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== mo - 1 || dt.getUTCDate() !== da || y < 1920 || dt > new Date())
    throw new UserError('Вкажіть правильну дату народження.');

  if (d.consent !== true) throw new UserError('Потрібна згода на показ фото та дати народження.');
  if (!(Number(d.elapsed) >= LIMITS.MIN_FILL_MS)) throw new UserError('Занадто швидко. Спробуйте ще раз.');

  let photo = null;
  if (d.photo) {
    const bytes = Utilities.base64Decode(String(d.photo));
    if (bytes.length > LIMITS.MAX_PHOTO_BYTES) throw new UserError('Фото завелике. Оберіть інше.');
    // JPEG починається з FF D8 FF (у Apps Script байти зі знаком, тому & 255)
    if (!(bytes.length > 3 && (bytes[0] & 255) === 0xFF && (bytes[1] & 255) === 0xD8 && (bytes[2] & 255) === 0xFF))
      throw new UserError('Фото має бути у форматі JPG.');
    photo = Utilities.newBlob(bytes, 'image/jpeg', 'photo.jpg');
  } else if (type === 'new') {
    throw new UserError('Додайте фото.');
  }

  return {
    type: type, lastName: lastName, firstName: firstName, patronymic: patronymic,
    birthdate: { iso: m[0], ua: m[3] + '.' + m[2] + '.' + m[1] },
    comment: clean(d.comment, 300), contact: clean(d.contact, 60), photo: photo
  };
}

/* Лічильники в кеші: захист від засмічення групи */
function checkRate_() {
  const lock = LockService.getScriptLock();
  lock.waitLock(5000);
  try {
    const cache = CacheService.getScriptCache();
    const hour = Number(cache.get('rate_h') || 0), six = Number(cache.get('rate_6h') || 0);
    if (hour >= LIMITS.PER_HOUR || six >= LIMITS.PER_6H)
      throw new UserError('Зараз надійшло забагато заявок. Спробуйте трохи пізніше.');
    if (!cache.get('rate_h')) cache.put('rate_h', '1', 3600); else cache.put('rate_h', String(hour + 1), 3600);
    if (!cache.get('rate_6h')) cache.put('rate_6h', '1', 21600); else cache.put('rate_6h', String(six + 1), 21600);
  } finally {
    lock.releaseLock();
  }
}

function countBad_() {
  const lock = LockService.getScriptLock();
  lock.waitLock(5000);
  try {
    const cache = CacheService.getScriptCache();
    const n = Number(cache.get('bad_code') || 0) + 1;
    cache.put('bad_code', String(n), 3600);
    if (n > LIMITS.BAD_CODE_PER_HOUR) throw new UserError('Забагато спроб. Спробуйте за годину.');
  } finally {
    lock.releaseLock();
  }
}

/* ───────────── Telegram ───────────── */

function send_(x) {
  const fio = [x.lastName, x.firstName, x.patronymic].filter(Boolean).join(' ');
  const when = Utilities.formatDate(new Date(), 'Europe/Kyiv', 'dd.MM.yyyy HH:mm');
  const lines = [
    x.type === 'new' ? '🎂 НОВА ЗАЯВКА' : '✏️ ЗМІНА ДАНИХ',
    '👤 ' + fio,
    '📅 ' + x.birthdate.ua + '  (' + x.birthdate.iso + ')'
  ];
  if (x.comment) lines.push('📝 ' + x.comment);
  if (x.contact) lines.push('📞 ' + x.contact);
  if (!x.photo) lines.push('📷 фото не додано');
  lines.push('🕒 ' + when);
  const text = lines.join('\n').slice(0, 1000);          // ліміт підпису в Telegram — 1024

  const base = { chat_id: prop_('CHAT_ID') };
  const topic = prop_('TOPIC_ID', true);
  if (topic) base.message_thread_id = topic;

  if (x.photo) tg_('sendPhoto', Object.assign({}, base, { photo: x.photo, caption: text }));
  else tg_('sendMessage', Object.assign({}, base, { text: text }));
}

function tg_(method, payload) {
  const res = UrlFetchApp.fetch('https://api.telegram.org/bot' + prop_('BOT_TOKEN') + '/' + method, {
    method: 'post', payload: payload, muteHttpExceptions: true
  });
  const body = res.getContentText();
  let ok = false;
  try { ok = JSON.parse(body).ok === true; } catch (e) {}
  if (!ok) throw new Error('Telegram ' + method + ': ' + body);   // у лог, клієнту не показуємо
}

/* ───────────── Службове ───────────── */

function prop_(name, optional) {
  const v = PropertiesService.getScriptProperties().getProperty(name);
  if (!v && !optional) throw new Error('Не задано властивість скрипта: ' + name);
  return v;
}

function reply_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

/** Запустіть вручну один раз: дасть дозволи й надішле в групу тестове повідомлення. */
function testTelegram() {
  const base = { chat_id: prop_('CHAT_ID'), text: '✅ Приймач заявок підключено' };
  const topic = prop_('TOPIC_ID', true);
  if (topic) base.message_thread_id = topic;
  tg_('sendMessage', base);
}
