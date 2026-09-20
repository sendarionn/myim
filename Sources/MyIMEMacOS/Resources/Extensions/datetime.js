// @myim-prefix 

function candidates(context) {
  const input = context.input.toLowerCase()
  if (input !== "calendar" &&
      (!context.settings.dateTimeCandidatesEnabled ||
       context.settings.dateTimeCandidatesEnabled[0] !== "true")) {
    return []
  }
  const dateFormats = ["YYYYMMDD", "M/D(E)"]
  const timeFormats = ["H:m", "H時m分"]
  const dayOffsets = {
    ototoi: -2,
    sakujitu: -1,
    kinou: -1,
    kyou: 0,
    asu: 1,
    ashita: 1,
    asatte: 2
  }
  const timeReadings = ["ima", "jikoku", "genzaijikoku"]
  const weekdayReadings = {
    nichi: "日",
    nichiyou: "日",
    nichiyoubi: "日",
    getsu: "月",
    getsuyou: "月",
    getsuyoubi: "月",
    ka: "火",
    kayou: "火",
    kayoubi: "火",
    sui: "水",
    suiyou: "水",
    suiyoubi: "水",
    moku: "木",
    mokuyou: "木",
    mokuyoubi: "木",
    kin: "金",
    kinyou: "金",
    kinyoubi: "金",
    do: "土",
    doyou: "土",
    doyoubi: "土"
  }
  const now = new Date(context.timestamp)

  if (input === "calendar") {
    return format(now, dateFormats)
  }
  if (Object.prototype.hasOwnProperty.call(dayOffsets, input)) {
    now.setDate(now.getDate() + dayOffsets[input])
    return format(now, dateFormats)
  }
  if (timeReadings.indexOf(input) >= 0) {
    return format(now, timeFormats)
  }
  if (Object.prototype.hasOwnProperty.call(weekdayReadings, input)) {
    return ["(" + weekdayReadings[input] + ")"]
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
