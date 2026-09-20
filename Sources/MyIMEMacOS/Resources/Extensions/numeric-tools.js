// @myim-prefix 

function candidates(context) {
  const input = context.input.trim().toLowerCase()
  const calculations = calculationCandidates(input)
  if (calculations.length > 0) {
    return calculations
  }
  return binaryCandidates(input)
    .concat(imperialLengthCandidates(input))
    .concat(reducedFractionCandidates(input))
}

function calculationCandidates(input) {
  if (input.length > 128 || !input.endsWith("=")) return []
  const expression = input.slice(0, -1)
  if (!expression || !/^[0-9.+\-*/()\s]+$/.test(expression)) return []
  const parser = arithmeticParser(expression.replace(/\s/g, ""))
  const value = parser.parse()
  if (value === null || !Number.isFinite(value) || Math.abs(value) > 1e15) {
    return []
  }
  const normalized = Math.abs(value) < 1e-12 ? 0 : value
  const result = formatCalculationNumber(normalized, 12)
  const values = [result].concat(groupedNumberCandidates(result))
  if (formatCalculationNumber(normalized, 12) !==
      formatCalculationNumber(normalized, 15)) {
    values.push("約" + formatCalculationNumber(
      roundToSignificantDigits(normalized, 1), 12
    ))
    values.push("約" + formatCalculationNumber(
      roundToSignificantDigits(normalized, 2), 12
    ))
  }
  return values.filter(function(value, index) {
    return values.indexOf(value) === index
  })
}

function arithmeticParser(expression) {
  let index = 0
  function parse() {
    const value = parseExpression()
    return value !== null && index === expression.length ? value : null
  }
  function parseExpression() {
    let value = parseTerm()
    if (value === null) return null
    while (current() === "+" || current() === "-") {
      const operation = current()
      index += 1
      const right = parseTerm()
      if (right === null) return null
      value = operation === "+" ? value + right : value - right
    }
    return value
  }
  function parseTerm() {
    let value = parseUnary()
    if (value === null) return null
    while (current() === "*" || current() === "/") {
      const operation = current()
      index += 1
      const right = parseUnary()
      if (right === null || (operation === "/" && right === 0)) return null
      value = operation === "*" ? value * right : value / right
    }
    return value
  }
  function parseUnary() {
    if (current() === "+") {
      index += 1
      return parseUnary()
    }
    if (current() === "-") {
      index += 1
      const value = parseUnary()
      return value === null ? null : -value
    }
    return parsePrimary()
  }
  function parsePrimary() {
    if (current() === "(") {
      index += 1
      const value = parseExpression()
      if (value === null || current() !== ")") return null
      index += 1
      return value
    }
    return parseNumber()
  }
  function parseNumber() {
    const start = index
    let decimalPoints = 0
    while (index < expression.length && /[0-9.]/.test(current())) {
      if (current() === ".") decimalPoints += 1
      if (decimalPoints > 1) return null
      index += 1
    }
    if (index === start) return null
    const token = expression.slice(start, index)
    if (!/^(?:\d+(?:\.\d*)?|\.\d+)$/.test(token)) return null
    const value = Number(token)
    return Number.isFinite(value) ? value : null
  }
  function current() {
    return index < expression.length ? expression[index] : null
  }
  return { parse: parse }
}

function formatCalculationNumber(value, significantDigits) {
  if (Number.isInteger(value)) return value.toFixed(0)
  return String(Number(value.toPrecision(significantDigits)))
}

function groupedNumberCandidates(value) {
  const match = value.match(/^([+-]?)(\d{4,})(\.\d+)?$/)
  if (!match) return []
  return [match[1] + match[2].replace(/\B(?=(\d{3})+(?!\d))/g, ",") +
    (match[3] || "")]
}

function roundToSignificantDigits(value, digits) {
  if (value === 0) return 0
  const scale = Math.pow(
    10,
    digits - 1 - Math.floor(Math.log10(Math.abs(value)))
  )
  return Math.round(value * scale) / scale
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
