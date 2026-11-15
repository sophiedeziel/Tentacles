import React from 'react'
import PropTypes from 'prop-types'

import LayoutDnd from '../LayoutDnd/LayoutDnd'
import Section, { SectionOverlay, SortableSection, WidgetOverlay } from '../Section/Section'
import { locate } from '../layout/layoutReducer'

// Edit mode's sections, from the draft: widgets drag within and between them, dividers drag among them
export default function EditableSections ({ editor, data }) {
  const { sections, dispatch } = editor
  const renderOverlay = (active) => {
    if (active.type === 'section') {
      const section = sections.find((candidate) => candidate.key === active.id)
      return section && <SectionOverlay section={section} />
    }
    const at = locate(sections, active.id)
    return at && <WidgetOverlay widget={sections[at.section].widgets[at.index]} data={data} />
  }

  return (
    <LayoutDnd sections={sections} dispatch={dispatch} renderOverlay={renderOverlay}>
      {sections.map((section, index) => {
        // The untitled first section has no divider to drag
        const Component = index === 0 ? Section : SortableSection
        return <Component key={section.key} section={section} index={index} data={data} editor={editor} />
      })}
    </LayoutDnd>
  )
}

EditableSections.propTypes = {
  editor: PropTypes.shape({ sections: PropTypes.array.isRequired, dispatch: PropTypes.func.isRequired }).isRequired,
  data: PropTypes.object.isRequired
}
