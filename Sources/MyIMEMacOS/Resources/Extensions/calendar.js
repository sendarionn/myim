// @myim-prefix calendar

function candidates(context) {
  if (context.input === "calendar-event") {
    return context.calendarEvents.map(formatCalendarEvent)
  }
  return []
}

function formatCalendarEvent(event) {
  return event.url ? event.title + " " + event.url : event.title
}
