// @myim-prefix gengou

function candidates(context) {
  if (context.input.toLowerCase() !== "gengou") {
    return []
  }

  const era = japaneseEra(new Date(context.timestamp))
  if (!era) {
    return []
  }
  return [
    era.name + eraYearText(era.year),
    era.symbol + String(era.year)
  ]
}

function japaneseEra(date) {
  const eras = [
    { name: "令和", symbol: "R", start: new Date(2019, 4, 1), baseYear: 2018 },
    { name: "平成", symbol: "H", start: new Date(1989, 0, 8), baseYear: 1988 },
    { name: "昭和", symbol: "S", start: new Date(1926, 11, 25), baseYear: 1925 },
    { name: "大正", symbol: "T", start: new Date(1912, 6, 30), baseYear: 1911 },
    { name: "明治", symbol: "M", start: new Date(1868, 0, 25), baseYear: 1867 }
  ]
  for (const era of eras) {
    if (date >= era.start) {
      return {
        name: era.name,
        symbol: era.symbol,
        year: date.getFullYear() - era.baseYear
      }
    }
  }
  return null
}

function eraYearText(year) {
  return year === 1 ? "元年" : String(year) + "年"
}
