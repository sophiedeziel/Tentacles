import React from 'react'
import PropTypes from 'prop-types'

import { BRAND_PURPLE, BRAND_PURPLE_LIGHT } from '../../Foundation/theme'
import { SUCKERS, TENTACLE_PATH } from './tentacle'

// The design system's colourings of the mark: purple for light surfaces, reversed for the dark navigation
const PALETTES = {
  default: { body: BRAND_PURPLE, sucker: '#b37feb', dot: '#531dab' },
  reversed: { body: BRAND_PURPLE_LIGHT, sucker: '#d3adf7', dot: BRAND_PURPLE }
}

// The Tentacles logo mark. Decorative by default; pass a title when it stands without the "Tentacles" name.
export default function TentacleMark ({ size = 32, variant = 'default', title, className }) {
  const { body, sucker, dot } = PALETTES[variant]
  const labelProps = title ? { role: 'img', 'aria-label': title } : { 'aria-hidden': true }

  return (
    <svg viewBox="0 0 64 64" width={size} height={size} className={className} {...labelProps}>
      <path d={TENTACLE_PATH} fill={body} />
      {SUCKERS.map(([cx, cy, outer, inner]) => (
        <g key={`${cx},${cy}`}>
          <circle cx={cx} cy={cy} r={outer} fill={sucker} />
          <circle cx={cx} cy={cy} r={inner} fill={dot} />
        </g>
      ))}
    </svg>
  )
}

TentacleMark.propTypes = {
  size: PropTypes.number,
  variant: PropTypes.oneOf(['default', 'reversed']),
  title: PropTypes.string,
  className: PropTypes.string
}
