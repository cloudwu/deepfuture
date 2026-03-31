import { zipSync } from 'fflate'

export interface FontStatusReporter {
  setProgress: (value: number) => void
  setStatus: (message: string, progressValue?: number) => void
}

export interface FontStrings {
  loadingChineseFont: string
  loadingEnglishFont: string
  localFontButton: string
  localFontUnavailable: string
  requestingLocalFont: string
  waitingLocalFontAuthorization: string
}

export interface PrepareFontZipOptions {
  fontPermissionButton: HTMLButtonElement | null
  resolveAssetUrl: (path: string) => string
  strings: FontStrings
  ui: FontStatusReporter
}

interface FontEntry {
  data: Uint8Array
  name: string
}

const ENGLISH_FONT_POSTSCRIPT_NAMES = ['ArialMT', 'LiberationSerif', 'Arial', 'Helvetica']
const CHINESE_FONT_POSTSCRIPT_NAMES = ['STYuanti-SC-Regular', 'MicrosoftYaHei', 'HeitiSC']
const FONT_NAME_SANITIZE_PATTERN = /[^\w.-]/g

function sanitizeFontName(name: string): string {
  return name.trim().replace(FONT_NAME_SANITIZE_PATTERN, '_')
}

async function fetchArrayBuffer(url: string): Promise<ArrayBuffer> {
  const response = await fetch(url)
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} while fetching ${url}`)
  }
  return response.arrayBuffer()
}

async function fetchFontEntry(url: string, fallbackName: string): Promise<FontEntry> {
  return {
    data: new Uint8Array(await fetchArrayBuffer(url)),
    name: fallbackName,
  }
}

async function getLocalFontEntry(postscriptNames: string[]): Promise<FontEntry | null> {
  const queryLocalFonts = window.queryLocalFonts
  if (!queryLocalFonts) {
    return null
  }

  const fonts = await queryLocalFonts({ postscriptNames })
  if (!fonts.length) {
    return null
  }

  const selected = postscriptNames
    .map(name => fonts.find((font: LocalFontData) => font.postscriptName === name))
    .find(Boolean) || fonts[0]

  const blob = await selected.blob()
  return {
    data: new Uint8Array(await blob.arrayBuffer()),
    name: sanitizeFontName(selected.postscriptName || selected.fullName || 'font'),
  }
}

async function waitForFontAuthorization(button: HTMLButtonElement | null, buttonLabel: string): Promise<void> {
  if (!button) {
    return
  }

  button.textContent = buttonLabel
  button.setAttribute('aria-label', buttonLabel)
  button.classList.add('visible')
  button.disabled = false

  await new Promise<void>((resolve) => {
    const onClick = () => {
      button.disabled = true
      button.removeEventListener('click', onClick)
      resolve()
    }

    button.addEventListener('click', onClick)
  })
}

async function loadBundledFonts(options: PrepareFontZipOptions): Promise<FontEntry[]> {
  options.ui.setStatus(options.strings.loadingEnglishFont, 66)
  const englishEntry = await fetchFontEntry(options.resolveAssetUrl('fonts/arial.ttf'), 'arial.ttf')
  options.ui.setProgress(74)

  options.ui.setStatus(options.strings.loadingChineseFont, 78)
  const chineseEntry = await fetchFontEntry(
    options.resolveAssetUrl('fonts/SourceHanSansSC-Regular.ttf'),
    'SourceHanSansSC-Regular.ttf',
  )
  options.ui.setProgress(86)

  return [englishEntry, chineseEntry]
}

function zipFontEntries(entries: FontEntry[]): Uint8Array {
  return zipSync(Object.fromEntries(
    entries.map(entry => [`asset/font/${entry.name.endsWith('.ttf') ? entry.name : `${entry.name}.ttf`}`, entry.data]),
  ))
}

export async function prepareFontZip(options: PrepareFontZipOptions): Promise<Uint8Array> {
  if (typeof window.queryLocalFonts !== 'function') {
    return zipFontEntries(await loadBundledFonts(options))
  }

  options.ui.setStatus(options.strings.waitingLocalFontAuthorization, 52)
  await waitForFontAuthorization(options.fontPermissionButton, options.strings.localFontButton)

  try {
    options.ui.setStatus(options.strings.requestingLocalFont, 58)
    const englishEntry = await getLocalFontEntry(ENGLISH_FONT_POSTSCRIPT_NAMES)
      ?? await fetchFontEntry(options.resolveAssetUrl('fonts/arial.ttf'), 'arial.ttf')
    options.ui.setProgress(74)

    const chineseEntry = await getLocalFontEntry(CHINESE_FONT_POSTSCRIPT_NAMES)
      ?? await fetchFontEntry(
        options.resolveAssetUrl('fonts/SourceHanSansSC-Regular.ttf'),
        'SourceHanSansSC-Regular.ttf',
      )
    options.ui.setProgress(86)

    return zipFontEntries([englishEntry, chineseEntry])
  }
  catch (error) {
    console.warn('Local font access failed, falling back to bundled font files', error)
    options.ui.setStatus(options.strings.localFontUnavailable, 60)
    return zipFontEntries(await loadBundledFonts(options))
  }
  finally {
    options.fontPermissionButton?.classList.remove('visible')
  }
}
