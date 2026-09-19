// @myim-prefix 

function candidates(context) {
  return []
}

function nextInputCandidates(context) {
  const input = context.input.trim()
  if (!/^[0-9０-９]+(?:[.,．，][0-9０-９]+)?$/.test(input)) {
    return []
  }
  return ["年", "円", "個", "人", "回", "日", "時", "分", "秒"]
}
