// @myim-exact bookmarks

function candidates() {
  return []
}

function bookmarkFormats(context) {
  const parameters = context.parameters || {}
  const title = String(parameters.title || "")
  const url = String(parameters.url || "")
  if (!url) {
    return []
  }
  const displayTitle = title || url
  return [
    {
      id: "url",
      label: "URL",
      text: url
    },
    {
      id: "linked-title",
      label: "リンク付きタイトル",
      text: displayTitle,
      linkURL: url
    },
    {
      id: "markdown",
      label: "Markdownリンク",
      text: "[" + escapeMarkdownLabel(displayTitle) + "](" + url + ")"
    }
  ]
}

function escapeMarkdownLabel(value) {
  return value.replace(/([\\\[\]])/g, "\\$1")
}
