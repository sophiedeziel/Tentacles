import React from 'react'
import PropTypes from 'prop-types'

import WidgetFrame from '../WidgetFrame/WidgetFrame'
import { REGISTRY, sizeOf } from '../widgets/registry'
import * as classes from './Section.module.less'

// A run of widgets under an optional divider title, laid out on the section's own grid
export default function Section ({ section, data }) {
  return (
    <section className={classes.section} aria-label={section.title || 'Top of dashboard'}>
      {section.title && <div className={classes.divider}>{section.title}</div>}
      <div className={classes.grid}>
        {section.widgets.map((widget) => {
          const entry = REGISTRY[widget.type]
          const size = sizeOf(widget)
          if (!entry?.Component || !size) return null

          const { Component } = entry
          return (
            <div key={widget.id} className={classes.cell} data-size={size} style={{
              '--width-units': widget.widthUnits,
              '--width-units-md': Math.min(widget.widthUnits, 2),
              '--height-units': widget.heightUnits
            }}>
              <WidgetFrame label={entry.name}>
                <Component widget={widget} size={size} data={data} />
              </WidgetFrame>
            </div>
          )
        })}
      </div>
    </section>
  )
}

Section.propTypes = {
  section: PropTypes.shape({
    id: PropTypes.string,
    title: PropTypes.string,
    widgets: PropTypes.arrayOf(PropTypes.shape({
      id: PropTypes.string,
      type: PropTypes.string.isRequired,
      widthUnits: PropTypes.number.isRequired,
      heightUnits: PropTypes.number.isRequired
    })).isRequired
  }).isRequired,
  data: PropTypes.object.isRequired
}
