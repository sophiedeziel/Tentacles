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

// A print's estimated length, from its seconds: "1 h 2 min" (seconds dropped past an hour), "30 min 28 s", "45 s"
export function formatPrintTime (seconds) {
  const total = Math.max(0, Math.round(seconds))
  if (total < 60) return `${total} s`
  if (total < 3600) {
    const left = total % 60
    return left ? `${Math.floor(total / 60)} min ${left} s` : `${total / 60} min`
  }
  const minutes = Math.round(total / 60)
  const left = minutes % 60
  return left ? `${Math.floor(minutes / 60)} h ${left} min` : `${minutes / 60} h`
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

// "Today, 17:58", "Yesterday, 20:02", "Nov 13, 14:10": when something happened, on the day it did, at `now`
export function formatDayClock (time, now) {
  const day = dayjs(time)
  const today = dayjs(now).startOf('day')
  if (!day.isBefore(today)) return `Today, ${formatClock(day)}`
  if (!day.isBefore(today.subtract(1, 'day'))) return `Yesterday, ${formatClock(day)}`
  return `${day.format('MMM D')}, ${formatClock(day)}`
}
