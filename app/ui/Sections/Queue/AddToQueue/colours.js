// The colour a G-code's hex reads as: the nearest of the named colours a filament is usually given (Filament's
// DEFAULT_COLOURS, Transparent aside, which no hex says). The Colour field is prefilled with it, so that the job asks
// for a name a loaded filament can match ("Black"), not a hex no printer has loaded.
//
//   nearestColourName('#1A1A1A') // => 'Black'
//   nearestColourName('FF8000')  // => 'Orange'
//   nearestColourName('nope')    // => null

// Each name's usual shade
const NAMED = {
  Black: [0, 0, 0],
  White: [255, 255, 255],
  Grey: [128, 128, 128],
  Silver: [192, 192, 192],
  Red: [220, 20, 20],
  Orange: [255, 128, 0],
  Yellow: [255, 220, 0],
  Green: [0, 160, 60],
  Blue: [0, 80, 220],
  Purple: [128, 0, 160],
  Pink: [255, 150, 190],
  Brown: [140, 80, 30]
}

// "#FF8800", "FF8800", "#F80" or "#FF8800AA" (the alpha dropped), as slicers write them; null for anything else
export function hexColour (hex) {
  const match = /^#?([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.exec((hex ?? '').trim())
  if (!match) return null
  const digits = match[1].length === 3 ? match[1].replace(/./g, (digit) => digit + digit) : match[1].slice(0, 6)
  return `#${digits.toUpperCase()}`
}

const rgb = (hex) => [0, 2, 4].map((start) => parseInt(hex.slice(1 + start, 3 + start), 16))

// The "redmean" distance: close to how far apart two colours look, without a colour space conversion
const distance = ([r1, g1, b1], [r2, g2, b2]) => {
  const mean = (r1 + r2) / 2
  const [r, g, b] = [r1 - r2, g1 - g2, b1 - b2]
  return Math.sqrt((2 + mean / 256) * r * r + 4 * g * g + (2 + (255 - mean) / 256) * b * b)
}

export function nearestColourName (hex) {
  const colour = hexColour(hex)
  if (!colour) return null
  const value = rgb(colour)
  let nearest = null
  Object.entries(NAMED).forEach(([name, shade]) => {
    const away = distance(value, shade)
    if (!nearest || away < nearest.away) nearest = { name, away }
  })
  return nearest.name
}

export const NAMED_COLOURS = Object.keys(NAMED)
