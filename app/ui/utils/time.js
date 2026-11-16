import dayjs from 'dayjs'
import duration from 'dayjs/plugin/duration'

dayjs.extend(duration)

const MINUTE = 60 * 1000
const HOUR = 60 * MINUTE
const DAY = 24 * HOUR

// When a print finishes: the snapshot's time plus the time left it reported (an ISO 8601 duration such as
// "PT1H12M"). Null when either is unknown.
export function doneAt (updatedAt, printTimeLeft) {
  if (!updatedAt || !printTimeLeft) return null
  const left = dayjs.duration(printTimeLeft)
  if (Number.isNaN(left.asMilliseconds())) return null
  return dayjs(updatedAt).add(left)
}

// "1 h 12 min", "3 h 05 min", "52 min", "< 1 min"
export function formatTimeLeft (milliseconds) {
  const minutes = Math.round(Math.max(0, milliseconds) / MINUTE)
  if (minutes < 1) return '< 1 min'
  if (minutes < 60) return `${minutes} min`
  const hours = Math.floor(minutes / 60)
  return `${hours} h ${String(minutes % 60).padStart(2, '0')} min`
}

// "14:35", on a 24-hour clock like the rest of the dashboard
export function formatClock (time) {
  return dayjs(time).format('HH:mm')
}

// "just now", "5 min ago", "2 h ago", "3 d ago"
export function formatAgo (time, now) {
  const elapsed = dayjs(now).diff(dayjs(time))
  if (elapsed < MINUTE) return 'just now'
  if (elapsed < HOUR) return `${Math.floor(elapsed / MINUTE)} min ago`
  if (elapsed < DAY) return `${Math.floor(elapsed / HOUR)} h ago`
  return `${Math.floor(elapsed / DAY)} d ago`
}
