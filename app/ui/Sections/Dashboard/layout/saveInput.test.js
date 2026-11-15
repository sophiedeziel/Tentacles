import { describe, expect, it } from 'vitest'
import layoutReducer, { draftFrom } from './layoutReducer'
import saveInput from './saveInput'

const LAYOUT = {
  sections: [
    {
      id: '1',
      title: null,
      widgets: [{
        id: '11', type: 'PRINT_QUEUE', widthUnits: 4, heightUnits: 2, printer: null,
        options: { __typename: 'PrintQueueWidgetOptions', nowPrinting: true, startNext: false, rowPerPrinter: false, history: true }
      }]
    },
    {
      id: '2',
      title: '  Workshop ',
      widgets: [{
        id: '21', type: 'PRINTER', widthUnits: 2, heightUnits: 1, printer: { id: '4' },
        options: { __typename: 'PrinterWidgetOptions', camera: false, timeLeft: true, temperatures: true, upNext: true, controls: true }
      }]
    }
  ]
}

describe('saveInput', () => {
  it('sends ids, spans, printers and typed options', () => {
    expect(saveInput(draftFrom(LAYOUT))).toEqual([
      {
        id: '1',
        title: null,
        widgets: [{
          id: '11', type: 'PRINT_QUEUE', widthUnits: 4, heightUnits: 2, printerId: null,
          options: { printQueue: { nowPrinting: true, startNext: false, rowPerPrinter: false, history: true } }
        }]
      },
      {
        id: '2',
        title: 'Workshop',
        widgets: [{
          id: '21', type: 'PRINTER', widthUnits: 2, heightUnits: 1, printerId: '4',
          options: { printer: { camera: false, timeLeft: true, temperatures: true, upNext: true, controls: true } }
        }]
      }
    ])
  })

  it('sends null ids for new sections and widgets, and no keys', () => {
    const draft = [
      { type: 'addDivider' },
      { type: 'addWidget', widgetType: 'PRINTER', size: 'S', printerId: '4' }
    ].reduce(layoutReducer, draftFrom(LAYOUT))
    const [, , added] = saveInput(draft)
    expect(added).toEqual({
      id: null,
      title: 'New Section',
      widgets: [{
        id: null, type: 'PRINTER', widthUnits: 1, heightUnits: 1, printerId: '4',
        options: { printer: { camera: false, timeLeft: true, temperatures: true, upNext: true, controls: true } }
      }]
    })
  })

  it('leaves out options the type does not declare, and missing ones', () => {
    const draft = draftFrom(LAYOUT)
    draft[1].widgets[0].options = { camera: true, nowPrinting: true, extra: 1 }
    expect(saveInput(draft)[1].widgets[0].options).toEqual({ printer: { camera: true } })
  })
})
