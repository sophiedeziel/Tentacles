import { describe, expect, it, vi } from 'vitest'
import { act, renderHook } from '@testing-library/react'

import { collisions, dragEndAction, dragOverAction } from './dragMoves'
import { useDragHandlers } from './LayoutDnd'
import layoutReducer, { draftFrom } from '../layout/layoutReducer'

const widget = (id) => ({ id, type: 'PRINTER', widthUnits: 1, heightUnits: 1, printer: { id: '1' }, options: {} })
const SECTIONS = draftFrom({
  sections: [
    { id: '1', title: null, widgets: [widget('a'), widget('b')] },
    { id: '2', title: 'Workshop', widgets: [widget('c')] },
    { id: '3', title: 'Garage', widgets: [] }
  ]
})

// dnd-kit's active and over items
const item = (id, data) => ({ id, data: { current: data } })
const dragged = (id) => item(`widget-${id}`, { type: 'widget' })
const overWidget = (id) => item(`widget-${id}`, { type: 'widget' })
const overEnd = (section) => item(`end:section-${section}`, { type: 'end', sectionKey: `section-${section}` })
const section = (id) => item(`section-${id}`, { type: 'section' })

describe('drag moves', () => {
  it('moves a widget into the section it is dragged over, before the widget under it', () => {
    expect(dragOverAction(SECTIONS, dragged('a'), overWidget('c')))
      .toEqual({ type: 'moveWidget', key: 'widget-a', sectionKey: 'section-2', index: 0 })
    expect(dragOverAction(SECTIONS, dragged('a'), overEnd(3)))
      .toEqual({ type: 'moveWidget', key: 'widget-a', sectionKey: 'section-3', index: 0 })
  })

  it('moves a widget within its section as it goes, and on drop', () => {
    expect(dragOverAction(SECTIONS, dragged('a'), overWidget('b')))
      .toEqual({ type: 'moveWidget', key: 'widget-a', sectionKey: 'section-1', index: 1 })
    expect(dragOverAction(SECTIONS, dragged('a'), dragged('a'))).toBeNull()
    expect(dragOverAction(SECTIONS, dragged('a'), null)).toBeNull()
    expect(dragOverAction(SECTIONS, section('2'), section('3'))).toBeNull()
    expect(dragEndAction(SECTIONS, dragged('a'), overWidget('b')))
      .toEqual({ type: 'moveWidget', key: 'widget-a', sectionKey: 'section-1', index: 1 })
    expect(dragEndAction(SECTIONS, dragged('a'), overEnd(1)))
      .toEqual({ type: 'moveWidget', key: 'widget-a', sectionKey: 'section-1', index: 2 })
  })

  it('moves a dragged divider to the section it is dropped on', () => {
    expect(dragEndAction(SECTIONS, section('3'), section('2'))).toEqual({ type: 'moveSection', key: 'section-3', index: 1 })
    expect(dragEndAction(SECTIONS, section('3'), null)).toBeNull()
  })

  it('lands widgets on widgets and section ends, and dividers on dividers', () => {
    const rect = { top: 0, left: 0, bottom: 10, right: 10, width: 10, height: 10 }
    const containers = [overWidget('b'), overEnd(1), section('2')]
    const droppableRects = new Map(containers.map((container) => [container.id, rect]))
    const ids = (active) => collisions({
      active, collisionRect: rect, droppableRects, droppableContainers: containers, pointerCoordinates: null
    }).map((collision) => collision.id)
    expect(ids(dragged('a'))).toEqual(['widget-b', 'end:section-1'])
    expect(ids(section('3'))).toEqual(['section-2'])
  })
})

describe('useDragHandlers', () => {
  const setup = () => {
    let sections = SECTIONS
    let now = 1000
    const dispatch = vi.fn((action) => { sections = layoutReducer(sections, action) })
    const hook = renderHook(() => useDragHandlers(sections, dispatch, () => now))
    const rerender = () => hook.rerender()
    return { hook, dispatch, rerender, current: () => sections, tick: (ms) => { now += ms } }
  }

  it('moves a widget across sections while dragging and restores the snapshot on Esc', () => {
    const { hook, dispatch, rerender, current } = setup()
    act(() => hook.result.current.onDragStart({ active: dragged('a') }))
    expect(hook.result.current.active).toEqual({ id: 'widget-a', type: 'widget' })
    act(() => hook.result.current.onDragOver({ active: dragged('a'), over: overWidget('c') }))
    rerender()
    expect(current()[1].widgets.map((moved) => moved.id)).toEqual(['a', 'c'])
    act(() => hook.result.current.onDragCancel())
    expect(dispatch).toHaveBeenLastCalledWith({ type: 'restore', sections: SECTIONS })
    expect(current()).toBe(SECTIONS)
    expect(hook.result.current.active).toBeNull()
  })

  it('waits between live moves, and longer to move back over the same widget', () => {
    const { hook, rerender, current, tick } = setup()
    const over = (target) => act(() => hook.result.current.onDragOver({ active: dragged('a'), over: target }))
    const order = () => current()[0].widgets.map((moved) => moved.id)
    act(() => hook.result.current.onDragStart({ active: dragged('a') }))
    over(overWidget('b'))
    rerender()
    expect(order()).toEqual(['b', 'a'])
    tick(100)
    over(overEnd(2))
    rerender()
    expect(current()[1].widgets).toHaveLength(1)
    tick(100)
    over(overWidget('b'))
    rerender()
    expect(order()).toEqual(['b', 'a'])
    tick(300)
    over(overWidget('b'))
    rerender()
    expect(order()).toEqual(['a', 'b'])
  })

  it('restores the snapshot when the drop is outside every target', () => {
    const { hook, dispatch } = setup()
    act(() => hook.result.current.onDragStart({ active: dragged('a') }))
    act(() => hook.result.current.onDragEnd({ active: dragged('a'), over: null }))
    expect(dispatch).toHaveBeenLastCalledWith({ type: 'restore', sections: SECTIONS })
  })

  it('makes the move on drop', () => {
    const { hook, current } = setup()
    act(() => hook.result.current.onDragStart({ active: dragged('a') }))
    act(() => hook.result.current.onDragEnd({ active: dragged('a'), over: overWidget('b') }))
    expect(current()[0].widgets.map((moved) => moved.id)).toEqual(['b', 'a'])
  })
})
