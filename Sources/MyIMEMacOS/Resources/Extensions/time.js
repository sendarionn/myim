// @myim-prefix time

function candidates(context) {
  if (context.input !== "time") return []
  const parameters = context.parameters || {}
  const hour = Number(parameters.hour)
  const minute = Number(parameters.minute)
  if (!Number.isInteger(hour) || hour < 0 || hour > 23 ||
      !Number.isInteger(minute) || minute < 0 || minute > 59) {
    return []
  }

  const formats = ["HH:mm", "H:mm", "H時m分", "HHmm", "h:mm a"]
  return formats.map(function(template) {
    return formatTime(hour, minute, template)
  })
}

function formatTime(hour, minute, template) {
  const twelveHour = hour % 12 || 12
  const values = {
    HH: pad(hour, 2),
    H: String(hour),
    mm: pad(minute, 2),
    m: String(minute),
    h: String(twelveHour),
    a: hour < 12 ? "AM" : "PM"
  }
  const tokens = ["HH", "mm", "H", "m", "h", "a"]
  return tokens.reduce(function(result, token) {
    return result.split(token).join(values[token])
  }, template)
}

function pad(value, length) {
  return String(value).padStart(length, "0")
}
