// @myim-prefix nendo

function candidates(context) {
  if (context.input.toLowerCase() !== "nendo") {
    return []
  }

  const now = new Date(context.timestamp)
  const fiscalYear = now.getMonth() < 3
    ? now.getFullYear() - 1
    : now.getFullYear()
  const era = japaneseEra(new Date(fiscalYear, 6, 1))
  const values = [String(fiscalYear) + "年度"]

  if (era) {
    values.push(era.name + eraYearText(era.year) + "年度")
  }
  return values
}

function japaneseEra(date) {
  const eras = [
    { name: "令和", start: new Date(2019, 4, 1), baseYear: 2018 },
    { name: "平成", start: new Date(1989, 0, 8), baseYear: 1988 },
    { name: "昭和", start: new Date(1926, 11, 25), baseYear: 1925 },
    { name: "大正", start: new Date(1912, 6, 30), baseYear: 1911 },
    { name: "明治", start: new Date(1868, 0, 25), baseYear: 1867 }
  ]
  for (const era of eras) {
    if (date >= era.start) {
      return {
        name: era.name,
        year: date.getFullYear() - era.baseYear
      }
    }
  }
  return null
}

function eraYearText(year) {
  return year === 1 ? "元" : String(year)
}
