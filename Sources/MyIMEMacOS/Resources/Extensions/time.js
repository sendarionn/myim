// @myim-prefix time
// @myim-prefix 0
// @myim-prefix 1
// @myim-prefix 2

function candidates(context) {
  const time = parseTime(context)
  if (!time) return []

  // HH:MM is offered unless it is exactly what was typed
  return formatTime(
    time.hour,
    time.minute,
    !context.input.includes(":"),
    context.input === "time"
  )
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

function formatTime(hour, minute, includesNumericFormat, includesPreferenceID) {
  return timeFormats(hour, minute).filter(function(format) {
    return includesNumericFormat || format.kind !== "numeric"
  }).map(function(format) {
    if (!includesPreferenceID) return format.text
    return {
      value: format.text,
      preferenceID: "time_ui:single:" + format.kind
    }
  })
}

// The clock's formats of a time, each with its kind so the two ends of a
// range can take the same one; 半 only at 30 minutes
function timeFormats(hour, minute) {
  const formats = [
    { kind: "kanji", text: `${hour}時${minute}分` },
    { kind: "numeric", text: `${pad(hour, 2)}:${pad(minute, 2)}` }
  ]
  if (minute === 30) formats.push({ kind: "half", text: `${hour}時半` })
  return formats
}

function pad(value, length) {
  return String(value).padStart(length, "0")
}

// The formats offered for a range chosen on the clock's rail, given as
// minutes from 0:00; the end may be 24:00. Both ends take the same format
// of the clock, joined by each separator; a format that only one end has,
// such as 半, is left out. Ranges on the hour also come as hours alone,
// such as 13〜14時, ahead of them
const rangeSeparators = [
  { id: "wave", text: "〜" },
  { id: "hyphen", text: " - " },
  { id: "kara", text: "から" }
]

function timeRangeFormats(context) {
  const parameters = context.parameters || {}
  const start = Number(parameters.start)
  const end = Number(parameters.end)
  if (!Number.isInteger(start) || !Number.isInteger(end) ||
      start < 0 || start >= end || end > 24 * 60) {
    return []
  }
  const results = []
  if (start % 60 === 0 && end % 60 === 0) {
    for (const separator of rangeSeparators) {
      results.push({
        value: `${start / 60}${separator.text}${end / 60}時`,
        preferenceID: `time_ui:range:hour:${separator.id}`
      })
    }
  }
  const startFormats = rangeEndFormats(start)
  const endFormats = rangeEndFormats(end)
  for (const separator of rangeSeparators) {
    for (const startFormat of startFormats) {
      const endFormat = endFormats.find(function(format) {
        return format.kind === startFormat.kind
      })
      if (endFormat) {
        results.push({
          value: `${startFormat.text}${separator.text}${endFormat.text}`,
          preferenceID: `time_ui:range:${startFormat.kind}:${separator.id}`
        })
      }
    }
  }
  return results
}

function rangeEndFormats(minutes) {
  return timeFormats(Math.floor(minutes / 60), minutes % 60)
}
