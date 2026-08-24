// @myim-prefix calendar

function candidates(context) {
  if (context.input !== "calendar") return []

  const date = new Date(context.timestamp)
  const weekdays = ["日", "月", "火", "水", "木", "金", "土"]
  const values = {
    YYYY: pad(date.getFullYear(), 4),
    YY: pad(date.getFullYear() % 100, 2),
    MM: pad(date.getMonth() + 1, 2),
    M: String(date.getMonth() + 1),
    DD: pad(date.getDate(), 2),
    D: String(date.getDate()),
    E: weekdays[date.getDay()]
  }
  const formats = [
    "YYYYMMDD",
    "M/D(E)",
    "YYYY/MM/DD",
    "YYYY-MM-DD",
    "YYYY年M月D日",
    "YYYY年M月D日(E)",
    "M月D日(E)",
    "M/D"
  ]
  const tokens = ["YYYY", "YY", "MM", "DD", "M", "D", "E"]
  return formats.map(function(template) {
    return tokens.reduce(function(result, token) {
      return result.split(token).join(values[token])
    }, template)
  })
}

function pad(value, length) {
  return String(value).padStart(length, "0")
}
