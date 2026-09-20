// @myim-prefix 

function candidates(context) {
  const input = context.input.trim().toLowerCase()
  return binaryCandidates(input)
    .concat(imperialLengthCandidates(input))
    .concat(reducedFractionCandidates(input))
}

function binaryCandidates(input) {
  if (!/^[+-]?\d+$/.test(input)) {
    return []
  }
  const value = Number(input)
  if (!Number.isSafeInteger(value)) {
    return []
  }
  const sign = value < 0 ? "-" : ""
  return [sign + "0b" + Math.abs(value).toString(2)]
}

function imperialLengthCandidates(input) {
  const match = input.match(/^([+-]?(?:\d+(?:\.\d*)?|\.\d+))(mm|cm|km|m)$/)
  if (!match) {
    return []
  }
  const value = Number(match[1])
  if (!Number.isFinite(value)) {
    return []
  }
  const metresPerMetricUnit = {
    mm: 0.001,
    cm: 0.01,
    m: 1,
    km: 1000
  }
  const imperialUnits = [
    { symbol: "in", metres: 0.0254 },
    { symbol: "ft", metres: 0.3048 },
    { symbol: "yd", metres: 0.9144 },
    { symbol: "mi", metres: 1609.344 }
  ]
  const metres = value * metresPerMetricUnit[match[2]]
  return imperialUnits.map(function(unit) {
    return { value: metres / unit.metres, symbol: unit.symbol }
  }).filter(function(item) {
    return item.value === 0 || Math.abs(item.value) >= 0.01
  }).map(function(item) {
    return formatApproximate(item.value) + item.symbol
  })
}

function reducedFractionCandidates(input) {
  const match = input.match(/^([+-]?\d+)\s*\/\s*([+-]?\d+)$/)
  if (!match) {
    return []
  }
  let numerator = Number(match[1])
  let denominator = Number(match[2])
  if (!Number.isSafeInteger(numerator) ||
      !Number.isSafeInteger(denominator) || denominator === 0) {
    return []
  }
  if (denominator < 0) {
    numerator = -numerator
    denominator = -denominator
  }
  const divisor = greatestCommonDivisor(Math.abs(numerator), denominator)
  const reducedNumerator = numerator / divisor
  const reducedDenominator = denominator / divisor
  if (reducedNumerator === numerator && reducedDenominator === denominator) {
    return []
  }
  return [String(reducedNumerator) + "/" + String(reducedDenominator)]
}

function greatestCommonDivisor(left, right) {
  while (right !== 0) {
    const remainder = left % right
    left = right
    right = remainder
  }
  return left
}

function formatApproximate(value) {
  if (Number.isInteger(value)) {
    return String(value)
  }
  const absolute = Math.abs(value)
  const leadingZeroes = absolute > 0 && absolute < 1
    ? Math.max(0, Math.floor(-Math.log10(absolute)))
    : 0
  const decimalPlaces = Math.min(12, leadingZeroes + 1)
  const rounded = Number(value.toFixed(decimalPlaces))
  return "約" + String(rounded)
}
