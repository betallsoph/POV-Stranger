// ISO 8601 week in UTC — used for weekly rematch rule
function getISOWeekUTC(date) {
  const d = new Date(date);
  const utc = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const day = utc.getUTCDay() || 7;
  utc.setUTCDate(utc.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(utc.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((utc - yearStart) / 86400000 + 1) / 7);
  return { isoWeek: week, isoWeekYear: utc.getUTCFullYear() };
}

module.exports = { getISOWeekUTC };
