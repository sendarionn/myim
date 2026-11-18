// @myim-prefix time
// @myim-prefix 0
// @myim-prefix 1
// @myim-prefix 2

function candidates(context) {
  const time = parseTime(context)
  if (!time) return []

  // HH:MM is offered unless it is exactly what was typed
  return formatTime(time.hour, time.minute, !context.input.includes(":"))
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
  const results = [`${hour}時${minute}分`]
  if (includesNumericFormat) results.push(`${HH}:${mm}`)
  if (minute === 30) results.push(`${hour}時半`)
  return results
}

function pad(value, length) {
  return String(value).padStart(length, "0")
}

// The formats offered for a range chosen on the clock's rail, given as
// minutes from 0:00; the end may be 24:00. Hours alone when both ends are
// on the hour, otherwise H:MM
const rangeSeparators = ["〜", " - ", "から"]

function timeRangeFormats(context) {
  const parameters = context.parameters || {}
  const start = Number(parameters.start)
  const end = Number(parameters.end)
  if (!Number.isInteger(start) || !Number.isInteger(end) ||
      start < 0 || start >= end || end > 24 * 60) {
    return []
  }
  const onTheHour = start % 60 === 0 && end % 60 === 0
  return rangeSeparators.map(function(separator) {
    return onTheHour
      ? `${start / 60}${separator}${end / 60}時`
      : `${clockText(start)}${separator}${clockText(end)}`
  })
}

function clockText(minutes) {
  return `${Math.floor(minutes / 60)}:${pad(minutes % 60, 2)}`
}
