// @myim-prefix time
// @myim-prefix 0
// @myim-prefix 1
// @myim-prefix 2

function candidates(context) {
  const time = parseTime(context)
  if (!time) return []

  return formatTime(time.hour, time.minute, context.input === "time")
}

function parseTime(context) {
  let hour
  let minute
  if (context.input === "time") {
    const parameters = context.parameters || {}
    hour = Number(parameters.hour)
    minute = Number(parameters.minute)
  } else {
    // HH:MM or HHMM, as typed without the colon
    const match = context.input.match(/^(\d{2}):?(\d{2})$/)
    if (!match) return null
    hour = Number(match[1])
    minute = Number(match[2])
  }
  if (!Number.isInteger(hour) || hour < 0 || hour > 23 ||
      !Number.isInteger(minute) || minute < 0 || minute > 59) {
    return null
  }
  return { hour: hour, minute: minute }
}

function formatTime(hour, minute, includesNumericFormat) {
  const HH = pad(hour, 2)
  const mm = pad(minute, 2)
  const results = [`${HH}時${mm}分`]
  if (minute === 30) results.push(`${hour}時半`)
  if (includesNumericFormat) results.unshift(`${HH}:${mm}`)
  return results
}

function pad(value, length) {
  return String(value).padStart(length, "0")
}
