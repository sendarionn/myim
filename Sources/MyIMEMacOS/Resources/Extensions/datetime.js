// @myim-prefix 

function candidates(context) {
  if (!context.settings.dateTimeCandidatesEnabled ||
      context.settings.dateTimeCandidatesEnabled[0] !== "true") {
    return []
  }
  const dateFormats = ["YYYYMMDD", "M/DD"]
  const timeFormats = ["H:m", "H時m分"]
  const dayOffsets = {
    ototoi: -2,
    kinou: -1,
    kyou: 0,
    ashita: 1,
    asatte: 2
  }
  const timeReadings = ["ima", "jikoku", "genzaijikoku"]
  const input = context.input.toLowerCase()
  const now = new Date(context.timestamp)

  if (Object.prototype.hasOwnProperty.call(dayOffsets, input)) {
    now.setDate(now.getDate() + dayOffsets[input])
    return format(now, dateFormats)
  }
  if (timeReadings.indexOf(input) >= 0) {
    return format(now, timeFormats)
  }
  return []
}

function format(date, formats) {
  const weekdays = ["日", "月", "火", "水", "木", "金", "土"]
  const values = {
    E: weekdays[date.getDay()],
    YYYY: pad(date.getFullYear(), 4),
    YY: pad(date.getFullYear() % 100, 2),
    MM: pad(date.getMonth() + 1, 2),
    M: String(date.getMonth() + 1),
    DD: pad(date.getDate(), 2),
    D: String(date.getDate()),
    HH: pad(date.getHours(), 2),
    H: String(date.getHours()),
    mm: pad(date.getMinutes(), 2),
    m: String(date.getMinutes()),
    ss: pad(date.getSeconds(), 2),
    s: String(date.getSeconds())
  }
  const tokens = ["YYYY", "YY", "MM", "DD", "HH", "mm", "ss", "M", "D", "H", "m", "s", "E"]
  return formats.map(function(template) {
    return tokens.reduce(function(result, token) {
      return result.split(token).join(values[token])
    }, template)
  })
}

function pad(value, length) {
  return String(value).padStart(length, "0")
}
