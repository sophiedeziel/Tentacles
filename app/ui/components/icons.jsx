import React from 'react'
import Icon from '@ant-design/icons'

// Tentacles' own line icons, drawn on a 24 px grid like the design system's

const lineIcon = (paths) => function LineSvg () {
  return (
    <svg viewBox="0 0 24 24" width="1em" height="1em" fill="none" stroke="currentColor" strokeWidth="1.5"
      strokeLinecap="round" strokeLinejoin="round">
      {paths.map((d) => <path key={d} d={d} />)}
    </svg>
  )
}

const Printer3DSvg = lineIcon([
  'M4 21V3.5', 'M20 21V3.5', 'M4 6.5h16', 'M10.5 6.5h3v2.5h-3z', 'M11.2 9l.8 1.5.8-1.5', 'M6.5 18h11',
  'M10 18v-3h4v3', 'M2.5 21h19'
])

const PrintQueueSvg = lineIcon(['M3.5 6h11', 'M3.5 11h11', 'M3.5 16h6', 'M14 14v6l5-3z'])

export function Printer3DOutlined (props) {
  return <Icon component={Printer3DSvg} aria-label="3D printer" {...props} />
}

export function PrintQueueOutlined (props) {
  return <Icon component={PrintQueueSvg} aria-label="Print queue" {...props} />
}
