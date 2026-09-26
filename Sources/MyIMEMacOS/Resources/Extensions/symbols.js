function candidates(context) {
  const input = context.input.toLowerCase()
  return symbolNames[input] || []
}

const symbolNames = {
  "ongusutoro-mu": ["Å"],
  "ongusutoroomu": ["Å"],
  "be-ta": ["β"],
  "beeta": ["β"]
}
