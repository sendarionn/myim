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

  const HH = pad(hour, 2)
  const mm = pad(minute, 2)
  const results = [`${HH}:${mm}`, `${HH}時${mm}分`]
  if (minute === 30) results.push(`${hour}時半`)
  return results
}

function pad(value, length) {
  return String(value).padStart(length, "0")
}
