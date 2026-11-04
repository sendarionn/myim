// @myim-prefix eto
// @myim-exact ne
// @myim-exact nezumi
// @myim-exact ushi
// @myim-exact tora
// @myim-exact u
// @myim-exact usagi
// @myim-exact tatsu
// @myim-exact mi
// @myim-exact hebi
// @myim-exact uma
// @myim-exact hitsuji
// @myim-exact saru
// @myim-exact tori
// @myim-exact inu
// @myim-exact i
// @myim-exact inoshishi

// The twelve branches in order from 子, each with the readings it is typed
// with; 2020 is a 子 year and each calendar year moves one branch on
const branches = [
  { readings: ["ne", "nezumi"], kanji: "子", emoji: "🐭" },
  { readings: ["ushi"], kanji: "丑", emoji: "🐂" },
  { readings: ["tora"], kanji: "寅", emoji: "🐯" },
  { readings: ["u", "usagi"], kanji: "卯", emoji: "🐰" },
  { readings: ["tatsu"], kanji: "辰", emoji: "🐉" },
  { readings: ["mi", "hebi"], kanji: "巳", emoji: "🐍" },
  { readings: ["uma"], kanji: "午", emoji: "🐴" },
  { readings: ["hitsuji"], kanji: "未", emoji: "🐑" },
  { readings: ["saru"], kanji: "申", emoji: "🐒" },
  { readings: ["tori"], kanji: "酉", emoji: "🐓" },
  { readings: ["inu"], kanji: "戌", emoji: "🐕" },
  { readings: ["i", "inoshishi"], kanji: "亥", emoji: "🐗" }
]
const baseYear = 2020

function candidates(context) {
  const input = context.input.toLowerCase()
  if (input === "eto") {
    const year = new Date(context.timestamp).getFullYear()
    return yearCandidates(year, "current").concat(supplementary([
      "十二支",
      branches.map(function(branch) { return branch.kanji }).join(""),
      branches.map(function(branch) { return branch.emoji }).join("")
    ]))
  }
  const yearMatch = input.match(/^eto(\d{4})$/)
  if (yearMatch) {
    const year = Number(yearMatch[1])
    return year >= 1 ? yearCandidates(year, "year") : []
  }
  for (const branch of branches) {
    if (branch.readings.indexOf(input) >= 0) {
      return supplementary([branch.kanji, branch.emoji])
    }
  }
  return []
}

// After the dictionary words of the reading, so 鳥 stays ahead of 酉 and
// 干支 ahead of 十二支
function supplementary(values) {
  return values.map(function(value) {
    return { value: value, kind: "supplementary" }
  })
}

function branchForYear(year) {
  const index = ((year - baseYear) % 12 + 12) % 12
  return branches[index]
}

// The branch of a year changes with the year, so the order of kanji and
// emoji is learned rather than the characters themselves
function yearCandidates(year, mode) {
  const branch = branchForYear(year)
  return [
    {
      value: branch.kanji,
      kind: "dynamic_date_time",
      preferenceID: "dynamic_eto:" + mode + ":kanji"
    },
    {
      value: branch.emoji,
      kind: "dynamic_date_time",
      preferenceID: "dynamic_eto:" + mode + ":emoji"
    }
  ]
}
