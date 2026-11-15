// What each control asks before it runs. Anything that changes a print asks first: Pause, Resume and Start Next in
// a Popconfirm on the button, Cancel (it can't be undone) in a Modal. Connect and Reconnect don't touch a print,
// so they run directly. When the dashboard isn't live, each confirmation warns that the state shown may be old.
export default function confirmationFor (key, view, live = true) {
  const confirmation = baseConfirmation(key, view)
  if (confirmation && !live) confirmation.body = `${confirmation.body} Printer states may be out of date.`
  return confirmation
}

function baseConfirmation (key, view) {
  const job = view.headline
  switch (key) {
    case 'pause': return {
      kind: 'popconfirm', title: 'Pause this print?', ok: 'Pause Print', keep: 'Keep Printing',
      body: `${view.name} parks the print head at ${view.progress}% and keeps the bed warm.`
    }
    case 'resume': return {
      kind: 'popconfirm', title: 'Resume this print?', ok: 'Resume Print', keep: 'Stay Paused',
      body: `${job} continues from ${view.progress}% on ${view.name}.`
    }
    case 'startNext': return {
      kind: 'popconfirm', title: 'Start the next print?', ok: 'Start Print', keep: 'Not Now',
      body: `${view.nextJobName || 'The next job'} starts on ${view.name}. Make sure the bed is clear.`
    }
    case 'cancel': return {
      kind: 'modal', title: 'Cancel this print?', ok: 'Cancel Print',
      keep: view.family === 'PAUSED' ? 'Keep Paused' : 'Keep Printing',
      body: `${job} stops at ${view.progress}% and can’t be resumed. The file stays in your library.`
    }
    default: return null
  }
}
