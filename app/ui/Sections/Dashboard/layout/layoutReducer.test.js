import { afterEach, describe, expect, it, vi } from 'vitest'
import layoutReducer, { NEW_DIVIDER_TITLE, canStep, draftFrom, locate, newKey } from './layoutReducer'

const printer = (id, widthUnits = 2, heightUnits = 1) => ({
  __typename: 'DashboardWidget',
  id,
  type: 'PRINTER',
  widthUnits,
  heightUnits,
  printer: { __typename: 'Printer', id: '1' },
  options: { __typename: 'PrinterWidgetOptions', camera: false, timeLeft: true }
})

const LAYOUT = {
  sections: [
    { id: '1', title: null, widgets: [printer('11'), printer('12'), printer('13')] },
    { id: '2', title: 'Workshop', widgets: [printer('21')] },
    { id: '3', title: 'Garage', widgets: [printer('31'), printer('32')] }
  ]
}

// The widget ids of each section, and the section titles
const shape = (sections) => sections.map((section) => section.widgets.map((widget) => widget.id || 'new'))
const titles = (sections) => sections.map((section) => section.title)

const run = (...actions) => actions.reduce(layoutReducer, draftFrom(LAYOUT))

describe('layoutReducer', () => {
  afterEach(() => vi.unstubAllGlobals())

  describe('draftFrom', () => {
    it('keys each saved section and widget by its id, and drops typenames', () => {
      const draft = draftFrom(LAYOUT)
      expect(draft[1]).toMatchObject({ key: 'section-2', id: '2', title: 'Workshop' })
      expect(draft[0].widgets[0]).toEqual({
        key: 'widget-11', id: '11', type: 'PRINTER', widthUnits: 2, heightUnits: 1,
        printer: { id: '1' }, options: { camera: false, timeLeft: true }
      })
    })

    it('gives the unsaved default layout new keys and null ids', () => {
      const draft = draftFrom({ sections: [{ id: null, title: null, widgets: [{ ...printer(null), printer: null }] }] })
      expect(draft[0].id).toBeNull()
      expect(draft[0].key).toBeTruthy()
      expect(draft[0].widgets[0]).toMatchObject({ id: null, printer: null })
      expect(draft[0].widgets[0].key).not.toBe(draft[0].key)
    })

    it('leaves out widget types it does not know', () => {
      const draft = draftFrom({ sections: [{ id: '1', title: null, widgets: [printer('11'), { ...printer('12'), type: 'CAMERA' }] }] })
      expect(shape(draft)).toEqual([['11']])
    })

    it('always starts with an untitled section', () => {
      expect(titles(draftFrom({ sections: [] }))).toEqual([null])
      expect(titles(draftFrom({ sections: [{ id: '2', title: 'Workshop', widgets: [] }] }))).toEqual([null, 'Workshop'])
    })
  })

  it('makes keys without crypto.randomUUID (plain http on the LAN)', () => {
    vi.stubGlobal('crypto', {})
    const keys = [newKey(), newKey()]
    expect(keys[0]).toMatch(/^new-/)
    expect(keys[0]).not.toBe(keys[1])
  })

  describe('moving widgets', () => {
    it('moves a widget within its section', () => {
      expect(shape(run({ type: 'moveWidget', key: 'widget-11', sectionKey: 'section-1', index: 2 })))
        .toEqual([['12', '13', '11'], ['21'], ['31', '32']])
    })

    it('moves a widget into another section', () => {
      expect(shape(run({ type: 'moveWidget', key: 'widget-12', sectionKey: 'section-3', index: 1 })))
        .toEqual([['11', '13'], ['21'], ['31', '12', '32']])
    })

    it('moves a widget into an empty section and clamps the index', () => {
      const sections = run({ type: 'addDivider' }, { type: 'moveWidget', key: 'widget-21', sectionKey: 'section-1', index: 99 })
      expect(shape(sections)).toEqual([['11', '12', '13', '21'], [], ['31', '32'], []])
      const empty = sections[3].key
      expect(shape(layoutReducer(sections, { type: 'moveWidget', key: 'widget-11', sectionKey: empty, index: 0 })))
        .toEqual([['12', '13', '21'], [], ['31', '32'], ['11']])
    })

    it('returns the same draft when nothing moves', () => {
      const draft = draftFrom(LAYOUT)
      expect(layoutReducer(draft, { type: 'moveWidget', key: 'widget-12', sectionKey: 'section-1', index: 1 })).toBe(draft)
      expect(layoutReducer(draft, { type: 'moveWidget', key: 'missing', sectionKey: 'section-1', index: 0 })).toBe(draft)
    })

    it('keeps the sections a move does not touch', () => {
      const draft = draftFrom(LAYOUT)
      const moved = layoutReducer(draft, { type: 'moveWidget', key: 'widget-11', sectionKey: 'section-1', index: 1 })
      expect(moved[1]).toBe(draft[1])
      expect(moved[2]).toBe(draft[2])
    })

    it('steps a widget with ‹ and ›, across dividers', () => {
      expect(shape(run({ type: 'stepWidget', key: 'widget-12', step: 1 }))).toEqual([['11', '13', '12'], ['21'], ['31', '32']])
      expect(shape(run({ type: 'stepWidget', key: 'widget-13', step: 1 }))).toEqual([['11', '12'], ['13', '21'], ['31', '32']])
      expect(shape(run({ type: 'stepWidget', key: 'widget-21', step: -1 }))).toEqual([['11', '12', '13', '21'], [], ['31', '32']])
    })

    it('stops ‹ at the first widget and › at the last', () => {
      const draft = draftFrom(LAYOUT)
      expect(canStep(draft, 'widget-11', -1)).toBe(false)
      expect(canStep(draft, 'widget-11', 1)).toBe(true)
      expect(canStep(draft, 'widget-32', 1)).toBe(false)
      expect(layoutReducer(draft, { type: 'stepWidget', key: 'widget-32', step: 1 })).toBe(draft)
    })
  })

  describe('resizing', () => {
    it('sets the span of a size the type supports, and keeps the options', () => {
      const sections = run({ type: 'resizeWidget', key: 'widget-21', size: 'XL' })
      expect(sections[1].widgets[0]).toMatchObject({ widthUnits: 4, heightUnits: 2, options: { camera: false } })
    })

    it('gives the options only the new size shows that size\'s default', () => {
      const queue = (id, widthUnits, heightUnits, options) => ({
        ...printer(id, widthUnits, heightUnits), type: 'PRINT_QUEUE', printer: null, options
      })
      const draft = draftFrom({ sections: [{ id: '1', title: null, widgets: [
        queue('11', 2, 2, { nowPrinting: false, startNext: true, rowPerPrinter: false, history: false }),
        queue('12', 4, 2, { nowPrinting: true, startNext: true, rowPerPrinter: false, history: false })
      ] }] })

      // Large shows neither option, so growing to Extra Large turns on its table; the options Large showed stay
      const grown = layoutReducer(draft, { type: 'resizeWidget', key: 'widget-11', size: 'XL' })
      expect(grown[0].widgets[0].options).toEqual({ nowPrinting: false, startNext: true, rowPerPrinter: true, history: true })

      // Extra Large showed them, so turned off they stay off at 4×4
      const bigger = layoutReducer(draft, { type: 'resizeWidget', key: 'widget-12', size: 'XXL' })
      expect(bigger[0].widgets[1].options).toMatchObject({ rowPerPrinter: false, history: false })
    })

    it('turns a small printer\'s camera on when it grows to Large, like a new Large one', () => {
      const draft = draftFrom({ sections: [{ id: '1', title: null, widgets: [printer('11', 1, 1)] }] })
      expect(layoutReducer(draft, { type: 'resizeWidget', key: 'widget-11', size: 'L' })[0].widgets[0].options)
        .toMatchObject({ camera: true, timeLeft: true })
    })

    it('ignores a size the type does not support', () => {
      const draft = draftFrom(LAYOUT)
      expect(layoutReducer(draft, { type: 'resizeWidget', key: 'widget-21', size: 'XXL' })).toBe(draft)
    })
  })

  it('sets the printer and options from the gear menu', () => {
    const sections = run(
      { type: 'setPrinter', key: 'widget-11', printerId: '7' },
      { type: 'setOption', key: 'widget-11', option: 'camera', value: true }
    )
    expect(sections[0].widgets[0]).toMatchObject({ printer: { id: '7' }, options: { camera: true, timeLeft: true } })
    expect(run({ type: 'setPrinter', key: 'widget-11', printerId: null })[0].widgets[0].printer).toBeNull()
  })

  it('adds a widget with its default options at the end of the last section', () => {
    const sections = run({ type: 'addWidget', widgetType: 'PRINT_QUEUE', size: 'XL', printerId: null })
    expect(shape(sections)).toEqual([['11', '12', '13'], ['21'], ['31', '32', 'new']])
    expect(sections[2].widgets[2]).toMatchObject({
      id: null, type: 'PRINT_QUEUE', widthUnits: 4, heightUnits: 2, printer: null,
      options: { nowPrinting: true, startNext: true, rowPerPrinter: true, history: true }
    })
  })

  it('removes a widget', () => {
    expect(shape(run({ type: 'removeWidget', key: 'widget-12' }))).toEqual([['11', '13'], ['21'], ['31', '32']])
  })

  describe('dividers', () => {
    it('adds an empty divider at the end', () => {
      const sections = run({ type: 'addDivider' })
      expect(titles(sections)).toEqual([null, 'Workshop', 'Garage', NEW_DIVIDER_TITLE])
      expect(sections[3]).toMatchObject({ id: null, widgets: [] })
    })

    it('renames a divider', () => {
      expect(titles(run({ type: 'renameDivider', key: 'section-2', title: 'Bench' }))).toEqual([null, 'Bench', 'Garage'])
    })

    it('reorders dividers with their widgets, below the first section', () => {
      expect(shape(run({ type: 'stepDivider', key: 'section-3', step: -1 }))).toEqual([['11', '12', '13'], ['31', '32'], ['21']])
      const draft = draftFrom(LAYOUT)
      expect(layoutReducer(draft, { type: 'stepDivider', key: 'section-2', step: -1 })).toBe(draft)
      expect(layoutReducer(draft, { type: 'stepDivider', key: 'section-3', step: 1 })).toBe(draft)
      expect(titles(run({ type: 'moveSection', key: 'section-3', index: 0 }))).toEqual([null, 'Garage', 'Workshop'])
    })

    it('merges the widgets of a removed divider into the section above', () => {
      const sections = run({ type: 'removeDivider', key: 'section-3' })
      expect(titles(sections)).toEqual([null, 'Workshop'])
      expect(shape(sections)).toEqual([['11', '12', '13'], ['21', '31', '32']])
      const draft = draftFrom(LAYOUT)
      expect(layoutReducer(draft, { type: 'removeDivider', key: 'section-1' })).toBe(draft)
    })
  })

  it('restores a snapshot (a cancelled drag)', () => {
    const snapshot = draftFrom(LAYOUT)
    const dragged = layoutReducer(snapshot, { type: 'moveWidget', key: 'widget-11', sectionKey: 'section-3', index: 0 })
    expect(layoutReducer(dragged, { type: 'restore', sections: snapshot })).toBe(snapshot)
  })

  it('loads another layout (Reset Layout)', () => {
    const sections = run({ type: 'load', dashboard: { sections: [{ id: null, title: null, widgets: [] }] } })
    expect(shape(sections)).toEqual([[]])
  })

  it('finds a widget', () => {
    expect(locate(draftFrom(LAYOUT), 'widget-32')).toEqual({ section: 2, index: 1 })
    expect(locate(draftFrom(LAYOUT), 'missing')).toBeNull()
  })
})
