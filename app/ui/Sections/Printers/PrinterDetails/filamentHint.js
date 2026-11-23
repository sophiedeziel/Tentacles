// Loaded Filament's hint: how many waiting jobs ask for the loaded filament (its material and colour exactly; jobs
// for any colour of the material aren't counted, and still match). Null when the count isn't known.
export default function filamentHint ({ material, colour }, count) {
  if (count == null) return null
  const filament = `${material} ${colour}`
  if (count === 0) return `No waiting job asks for ${filament}. Any Colour jobs still match.`
  if (count === 1) return `1 waiting job asks for ${filament}.`
  return `${count} waiting jobs ask for ${filament}.`
}
