import { theme } from 'antd'

// Brand colours
export const BRAND_PURPLE = '#722ed1'
export const BRAND_PURPLE_LIGHT = '#a565ff'
export const BRAND_PURPLE_PALE = '#d3adf7'
export const BRAND_NIGHT = '#110028'
export const BRAND_NIGHT_DARK = '#080014'

// The side menu and header stay dark on every page
const layoutComponents = {
  Layout: {
    headerBg: BRAND_NIGHT,
    siderBg: BRAND_NIGHT,
    triggerBg: BRAND_NIGHT_DARK
  },
  Menu: {
    darkItemBg: BRAND_NIGHT,
    darkSubMenuItemBg: BRAND_NIGHT_DARK
  }
}

export const lightTheme = {
  algorithm: [theme.defaultAlgorithm],
  token: {
    colorPrimary: BRAND_PURPLE
  },
  components: layoutComponents
}

export const darkTheme = {
  algorithm: [theme.darkAlgorithm],
  token: {
    colorPrimary: BRAND_PURPLE_LIGHT
  },
  components: layoutComponents
}

// The printer state families, as named by the PrinterStateFamily GraphQL enum
export const STATE_FAMILIES = ['PRINTING', 'PAUSED', 'CANCELLING', 'OPERATIONAL', 'CONNECTING', 'ERROR', 'OFFLINE']

// The families a fleet flags as "Needs Attention". CONNECTING is left out: it settles on its own.
export const NEEDS_ATTENTION_FAMILIES = ['ERROR', 'OFFLINE', 'CANCELLING']

// One palette entry per state family:
// - color: progress rings and bars, status dots
// - tint: the light background behind a state icon or a large ring
// - tag: the antd Tag colour of the state tag (status presets where antd has one)
export const STATE_PALETTE = {
  PRINTING: { color: BRAND_PURPLE, tint: '#f9f0ff', tag: 'purple' },
  PAUSED: { color: '#faad14', tint: '#fffbe6', tag: 'warning' },
  CANCELLING: { color: '#fa8c16', tint: '#fff7e6', tag: 'orange' },
  OPERATIONAL: { color: '#52c41a', tint: '#f6ffed', tag: 'success' },
  CONNECTING: { color: '#1677ff', tint: '#e6f4ff', tag: 'processing' },
  ERROR: { color: '#ff4d4f', tint: '#fff2f0', tag: 'error' },
  OFFLINE: { color: '#8c8c8c', tint: '#f5f5f5', tag: 'default' }
}

// The palette entry of a state family. Unknown families read as OFFLINE.
export function statePalette (family) {
  return STATE_PALETTE[family] || STATE_PALETTE.OFFLINE
}
