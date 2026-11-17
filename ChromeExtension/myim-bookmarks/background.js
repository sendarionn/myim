// Sends this Chrome profile's bookmarks to myim through native messaging.
// The bookmarks go only to the myim host on this Mac.

const HOST_NAME = "io.github.sendarionn.myim.bookmarks"
const SYNC_DELAY_MS = 1000
let syncTimer = null

async function profileSettings() {
  const stored = await chrome.storage.local.get(["profileID", "profileName"])
  let profileID = stored.profileID
  if (!profileID) {
    profileID = crypto.randomUUID()
    await chrome.storage.local.set({ profileID })
  }
  return { profileID, profileName: stored.profileName || "Chrome" }
}

function flatten(nodes, folders, result) {
  for (const node of nodes) {
    if (node.url) {
      result.push({
        title: node.title || "",
        url: node.url,
        folderPath: folders.join(" / ")
      })
    } else if (node.children) {
      const next = node.title ? folders.concat(node.title) : folders
      flatten(node.children, next, result)
    }
  }
  return result
}

async function recordStatus(status) {
  await chrome.storage.local.set({ lastSync: status })
  await chrome.action.setBadgeText({ text: status.ok ? "" : "!" })
  if (!status.ok) {
    await chrome.action.setBadgeBackgroundColor({ color: "#d93025" })
  }
}

async function syncNow() {
  const { profileID, profileName } = await profileSettings()
  const tree = await chrome.bookmarks.getTree()
  const bookmarks = flatten(tree, [], [])
  const message = { type: "replaceBookmarks", profileID, profileName, bookmarks }
  try {
    const reply = await chrome.runtime.sendNativeMessage(HOST_NAME, message)
    const ok = Boolean(reply && reply.ok)
    await recordStatus({
      ok,
      at: new Date().toISOString(),
      count: ok ? reply.count : 0,
      error: ok ? null : (reply && reply.error) || "no-reply"
    })
  } catch (error) {
    // The host is missing, not registered for this extension, or failed
    await recordStatus({
      ok: false,
      at: new Date().toISOString(),
      count: 0,
      error: String(error && error.message ? error.message : error)
    })
  }
}

function scheduleSync() {
  if (syncTimer) clearTimeout(syncTimer)
  syncTimer = setTimeout(() => {
    syncTimer = null
    syncNow()
  }, SYNC_DELAY_MS)
}

chrome.runtime.onInstalled.addListener(scheduleSync)
chrome.runtime.onStartup.addListener(scheduleSync)
chrome.bookmarks.onCreated.addListener(scheduleSync)
chrome.bookmarks.onChanged.addListener(scheduleSync)
chrome.bookmarks.onMoved.addListener(scheduleSync)
chrome.bookmarks.onRemoved.addListener(scheduleSync)
chrome.bookmarks.onChildrenReordered.addListener(scheduleSync)
chrome.bookmarks.onImportEnded.addListener(scheduleSync)
chrome.action.onClicked.addListener(() => chrome.runtime.openOptionsPage())

chrome.runtime.onMessage.addListener((request, _sender, sendResponse) => {
  if (request && request.type === "syncNow") {
    syncNow().then(() => sendResponse({ done: true }))
    return true
  }
  return false
})
