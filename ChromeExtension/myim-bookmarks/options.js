const nameField = document.getElementById("profileName")
const statusView = document.getElementById("status")

async function render() {
  const { profileName, lastSync } = await chrome.storage.local.get([
    "profileName",
    "lastSync"
  ])
  nameField.value = profileName || "Chrome"
  if (!lastSync) {
    statusView.textContent = "まだ同期していません"
    statusView.className = ""
  } else if (lastSync.ok) {
    statusView.textContent =
      `同期済み: ${lastSync.count}件 (${new Date(lastSync.at).toLocaleString()})`
    statusView.className = ""
  } else {
    statusView.textContent =
      `myimへ接続できません: ${lastSync.error}\n` +
      "Scripts/install-chrome-bookmark-host.shでの登録を確認してください"
    statusView.className = "error"
  }
}

document.getElementById("save").addEventListener("click", async () => {
  await chrome.storage.local.set({ profileName: nameField.value.trim() || "Chrome" })
  statusView.textContent = "同期中…"
  await chrome.runtime.sendMessage({ type: "syncNow" })
  render()
})

render()
