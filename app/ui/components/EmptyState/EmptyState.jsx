import React from 'react'
import PropTypes from 'prop-types'
import { Empty } from 'antd'

import { BRAND_PURPLE, STATE_PALETTE } from '../../Foundation/theme'
import { SUCKERS, TENTACLE_PATH } from '../../Foundation/tentacle'
import * as classes from './EmptyState.module.less'

// The 3D printer line icon's frame, gantry and print head (components/icons), without the print on the bed
const PRINTER_PATHS = ['M4 21V3.5', 'M20 21V3.5', 'M4 6.5h16', 'M10.5 6.5h3v2.5h-3z', 'M11.2 9l.8 1.5.8-1.5',
  'M6.5 18h11', 'M2.5 21h19']

// An empty 3D printer in a soft circle, with a small tentacle curled up on its bed where the print would be
function PrintersIllustration () {
  return (
    <svg viewBox="0 0 160 120" width="160" height="120" aria-hidden="true">
      <circle cx="80" cy="62" r="52" fill={STATE_PALETTE.PRINTING.tint} />
      <g transform="translate(44 26) scale(3)" fill="none" stroke={BRAND_PURPLE} strokeWidth="0.85"
        strokeLinecap="round" strokeLinejoin="round">
        {PRINTER_PATHS.map((d) => <path key={d} d={d} />)}
      </g>
      <g transform="translate(68.5 60.2) scale(0.33)">
        <path d={TENTACLE_PATH} fill={BRAND_PURPLE} />
        {SUCKERS.map(([cx, cy, outer, inner]) => (
          <g key={`${cx},${cy}`}>
            <circle cx={cx} cy={cy} r={outer} fill="#b37feb" />
            <circle cx={cx} cy={cy} r={inner} fill="#531dab" />
          </g>
        ))}
      </g>
    </svg>
  )
}

// One illustration per kind of empty page; more kinds come with their pages (#2793)
const ILLUSTRATIONS = {
  printers: PrintersIllustration
}

// A page or card with nothing to show yet: an illustration for its `kind`, a title, a description, and what to do
// about it (buttons) as children, side by side
export default function EmptyState ({ kind, title, description, children }) {
  const Illustration = ILLUSTRATIONS[kind]

  return (
    <Empty
      image={<Illustration />}
      styles={{ image: { height: 120, marginBottom: 12 } }}
      description={
        <>
          <div className={classes.title}>{title}</div>
          {description && <div className={classes.description}>{description}</div>}
        </>
      }
    >
      {children && <div className={classes.actions}>{children}</div>}
    </Empty>
  )
}

EmptyState.propTypes = {
  kind: PropTypes.oneOf(Object.keys(ILLUSTRATIONS)).isRequired,
  title: PropTypes.string.isRequired,
  description: PropTypes.node,
  children: PropTypes.node
}
