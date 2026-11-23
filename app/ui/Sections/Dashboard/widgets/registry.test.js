import { describe, expect, it } from 'vitest'
import { REGISTRY, SIZES, sizeOf } from './registry'

const keys = (options) => options.map((option) => option.key)

describe('registry', () => {
  it('names each span', () => {
    expect(sizeOf({ widthUnits: 1, heightUnits: 1 })).toBe('S')
    expect(sizeOf({ widthUnits: 2, heightUnits: 1 })).toBe('M')
    expect(sizeOf({ widthUnits: 2, heightUnits: 2 })).toBe('L')
    expect(sizeOf({ widthUnits: 4, heightUnits: 2 })).toBe('XL')
    expect(sizeOf({ widthUnits: 4, heightUnits: 4 })).toBe('XXL')
    expect(sizeOf({ widthUnits: 3, heightUnits: 1 })).toBeNull()
  })

  it('has a span for every size a widget supports', () => {
    Object.values(REGISTRY).forEach((entry) => {
      entry.sizes.forEach((size) => expect(SIZES[size]).toBeDefined())
      expect(entry.sizes).toContain(entry.defaultSize)
    })
  })

  it('names a widget after its printer in edit mode', () => {
    expect(REGISTRY.PRINTER.title({ name: 'Prusa MK4' })).toBe('Prusa MK4')
    expect(REGISTRY.PRINT_QUEUE.title({ name: 'Prusa MK4' })).toBe('Prusa MK4 queue')
    expect(REGISTRY.PRINT_QUEUE.title(null)).toBe('Print Queue')
  })

  describe('Printer', () => {
    const printer = REGISTRY.PRINTER

    it('turns the camera on by default at Large and Extra Large only', () => {
      expect(printer.sizes.map((size) => printer.defaultOptions(size).camera)).toEqual([false, false, true, true])
    })
  })

  describe('Print Queue', () => {
    it('offers the options that fit each size', () => {
      const queue = REGISTRY.PRINT_QUEUE
      expect(keys(queue.optionsFor('S'))).toEqual([])
      expect(keys(queue.optionsFor('L'))).toEqual(['nowPrinting', 'startNext'])
      expect(keys(queue.optionsFor('XXL'))).toEqual(['nowPrinting', 'startNext', 'rowPerPrinter', 'history'])
    })

    it('turns one row per printer and history on by default at Extra Large and 4×4 only', () => {
      const queue = REGISTRY.PRINT_QUEUE
      expect(queue.sizes.map((size) => queue.defaultOptions(size).rowPerPrinter)).toEqual([false, false, false, true, true])
      expect(queue.sizes.map((size) => queue.defaultOptions(size).history)).toEqual([false, false, false, true, true])
      expect(queue.defaultOptions('XL')).toMatchObject({ nowPrinting: true, startNext: true })
    })
  })
})
