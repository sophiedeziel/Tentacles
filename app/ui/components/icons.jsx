import React from 'react'
import Icon from '@ant-design/icons'

// Tentacles' own line icons, drawn on a 24 px grid like the design system's: ant design has none for printers,
// hotends, beds or filament. Each one is labelled for screen readers; pass aria-hidden where it is decorative.

const lineIcon = (label, paths) => {
  function LineSvg () {
    return (
      <svg viewBox="0 0 24 24" width="1em" height="1em" fill="none" stroke="currentColor" strokeWidth="1.5"
        strokeLinecap="round" strokeLinejoin="round" focusable="false" aria-hidden="true">
        {paths.map((d) => <path key={d} d={d} />)}
      </svg>
    )
  }

  return function LineIcon (props) {
    return <Icon component={LineSvg} aria-label={label} {...props} />
  }
}

export const Printer3DOutlined = lineIcon('3D printer', [
  'M4 21V3.5', 'M20 21V3.5', 'M4 6.5h16', 'M10.5 6.5h3v2.5h-3z', 'M11.2 9l.8 1.5.8-1.5', 'M6.5 18h11',
  'M10 18v-3h4v3', 'M2.5 21h19'
])

export const HotendOutlined = lineIcon('Hotend / nozzle', [
  'M12 2.5V9', 'M8.5 4.5h7', 'M8.5 7h7', 'M6 9.5h12v5.5H6z', 'M10 15l1.2 3h1.6L14 15', 'M12 21h.01'
])

export const HeatedBedOutlined = lineIcon('Heated bed', [
  'M3.5 15.5h17a1 1 0 0 1 1 1v2a1 1 0 0 1-1 1h-17a1 1 0 0 1-1-1v-2a1 1 0 0 1 1-1z',
  'M8 12c-1.2-1.4 1.2-2.6 0-4s1.2-2.6 0-4', 'M12 12c-1.2-1.4 1.2-2.6 0-4s1.2-2.6 0-4',
  'M16 12c-1.2-1.4 1.2-2.6 0-4s1.2-2.6 0-4'
])

export const FilamentOutlined = lineIcon('Filament spool', [
  'M10.5 3.5a8 8 0 1 0 0 16a8 8 0 1 0 0-16z', 'M10.5 8.5a3 3 0 1 0 0 6a3 3 0 1 0 0-6z',
  'M13.5 4.1c4.5 1.5 7 5.5 7.5 16.4'
])

export const LayersOutlined = lineIcon('Layers', ['M5 20h14', 'M6 16.5h12', 'M7.5 13h9', 'M9 9.5h6', 'M10.5 6h3'])

export const ExtruderOutlined = lineIcon('Extruder', [
  'M9 6.5a5.5 5.5 0 1 0 0 11a5.5 5.5 0 1 0 0-11z', 'M9 10.5a1.5 1.5 0 1 0 0 3a1.5 1.5 0 1 0 0-3z',
  'M18.5 10a2 2 0 1 0 0 4a2 2 0 1 0 0-4z', 'M15.5 2.5v19'
])

export const PrintQueueOutlined = lineIcon('Print queue', ['M3.5 6h11', 'M3.5 11h11', 'M3.5 16h6', 'M14 14v6l5-3z'])

export const GcodeFileOutlined = lineIcon('G-code file', [
  'M14 2.5H7a2 2 0 0 0-2 2v15a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-12z', 'M14 2.5v5h5', 'M14.3 12.9a3 3 0 1 0 .7 2.1h-2.5'
])

export const WebcamOutlined = lineIcon('Webcam', [
  'M12 3a6.5 6.5 0 1 0 0 13a6.5 6.5 0 1 0 0-13z', 'M12 7a2.5 2.5 0 1 0 0 5a2.5 2.5 0 1 0 0-5z', 'M12 16v4.5',
  'M8 21h8'
])

export const TemperatureOutlined = lineIcon('Temperature', [
  'M10 13.6V5a2 2 0 0 1 4 0v8.6a4 4 0 1 1-4 0z', 'M12 9v8'
])
