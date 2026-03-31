import { startApp } from './bootstrap'
import chsLocale from './locales/chs.json'
import enLocale from './locales/en.json'
import './style.css'

const baseUrl = new URL(import.meta.env.BASE_URL, window.location.href)

type LocaleStrings = typeof enLocale
type LocaleKey = 'chs' | 'en'

const LOCALES: Record<LocaleKey, LocaleStrings> = {
  chs: chsLocale,
  en: enLocale,
}

function resolveLocaleKey(language: string | undefined): LocaleKey {
  const normalized = (language || '').toLowerCase()
  if (normalized.startsWith('zh')) {
    return 'chs'
  }
  return 'en'
}

const strings = LOCALES[resolveLocaleKey(navigator.language)] || LOCALES.en

function resolveAssetUrl(path: string): string {
  return new URL(path, baseUrl).href
}

function requireElement<T extends Element>(selector: string): T {
  const element = document.querySelector<T>(selector)
  if (!element) {
    throw new Error(`Missing required element: ${selector}`)
  }
  return element
}

const app = document.querySelector<HTMLDivElement>('#app')
if (!app) {
  throw new Error('Missing #app root element.')
}

app.innerHTML = `
  <div id="overlay">
    <div class="overlay-content">
      <h1 id="overlay-title"></h1>
      <div id="overlay-intro"></div>
      <p id="overlay-status"></p>
      <div id="overlay-progress" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0">
        <div id="overlay-progress-track">
          <div id="overlay-progress-fill"></div>
        </div>
        <span id="overlay-progress-label">0%</span>
      </div>
      <button id="font-permission-btn" type="button"></button>
    </div>
  </div>
  <canvas id="canvas"></canvas>
  <div id="metrics" aria-live="polite" aria-expanded="false">
    <a
      id="source-link"
      href="https://github.com/cloudwu/deepfuture"
      target="_blank"
      rel="noopener noreferrer"
      aria-label="Source code on GitHub"
    >
      <svg viewBox="0 0 16 16" aria-hidden="true">
        <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0 0 16 8c0-4.42-3.58-8-8-8" />
      </svg>
    </a>
    <div class="metrics-details">
      <span class="separator" aria-hidden="true">/</span>
      <label id="uv_label" data-hint="UV" aria-label="Unique Visitors" title="UV"></label>
      <span class="separator" aria-hidden="true">/</span>
      <label id="pv_label" data-hint="PV" aria-label="Page Views" title="PV"></label>
    </div>
  </div>
`

const overlay = requireElement<HTMLElement>('#overlay')
const titleEl = requireElement<HTMLElement>('#overlay-title')
const introEl = requireElement<HTMLElement>('#overlay-intro')
const statusEl = requireElement<HTMLElement>('#overlay-status')
const progressEl = requireElement<HTMLElement>('#overlay-progress')
const progressFillEl = requireElement<HTMLElement>('#overlay-progress-fill')
const progressLabelEl = requireElement<HTMLElement>('#overlay-progress-label')
const fontPermissionBtn = document.querySelector<HTMLButtonElement>('#font-permission-btn')
const sourceLinkEl = document.querySelector<HTMLAnchorElement>('#source-link')
const metrics = document.querySelector<HTMLElement>('#metrics')
const uvLabel = document.querySelector<HTMLElement>('#uv_label')
const pvLabel = document.querySelector<HTMLElement>('#pv_label')
const canvas = requireElement<HTMLCanvasElement>('#canvas')

let lastProgressValue = 0

canvas.addEventListener('contextmenu', (event) => {
  event.preventDefault()
})

function attachLabelSanitizer(label: HTMLElement | null, prefix: string): void {
  if (!label) {
    return
  }

  const config = { childList: true, characterData: true, subtree: true }
  const regex = new RegExp(`^\\s*${prefix}\\s*[:：\\-–]?\\s*`, 'i')
  let observer: MutationObserver

  const apply = () => {
    const raw = label.textContent || ''
    if (!raw) {
      return
    }
    const cleaned = raw.replace(regex, '').trim()
    if (cleaned !== raw) {
      observer.disconnect()
      label.textContent = cleaned
      observer.observe(label, config)
    }
  }

  observer = new MutationObserver(apply)
  observer.observe(label, config)
  apply()
}

function setProgress(value: number): void {
  const clamped = Math.max(0, Math.min(100, value))
  const nextValue = Math.max(lastProgressValue, clamped)
  lastProgressValue = nextValue
  const rounded = Math.round(nextValue)

  progressFillEl.style.width = `${nextValue}%`
  progressEl.setAttribute('aria-valuenow', String(rounded))
  progressEl.setAttribute('aria-valuetext', `${rounded}%`)
  progressLabelEl.textContent = `${rounded}%`
}

function setStatus(message: string, progressValue?: number): void {
  statusEl.textContent = message
  if (typeof progressValue === 'number') {
    setProgress(progressValue)
  }
}

function showError(title: string, detail: string): void {
  overlay.classList.remove('hidden')
  overlay.classList.add('error')
  titleEl.textContent = title
  setStatus(detail)
}

function hideOverlay(): void {
  overlay.classList.add('hidden')
}

async function start(): Promise<void> {
  attachLabelSanitizer(uvLabel, 'uv')
  attachLabelSanitizer(pvLabel, 'pv')

  metrics?.addEventListener('mouseenter', () => metrics.setAttribute('aria-expanded', 'true'))
  metrics?.addEventListener('mouseleave', () => metrics.setAttribute('aria-expanded', 'false'))
  metrics?.addEventListener('focusin', () => metrics.setAttribute('aria-expanded', 'true'))
  metrics?.addEventListener('focusout', () => {
    if (!metrics.contains(document.activeElement)) {
      metrics.setAttribute('aria-expanded', 'false')
    }
  })

  titleEl.textContent = strings.gameTitle
  introEl.innerHTML = strings.intro.map(text => `<p>${text}</p>`).join('')
  sourceLinkEl?.setAttribute('aria-label', strings.sourceAriaLabel)
  await startApp({
    canvas,
    fontPermissionButton: fontPermissionBtn,
    hideOverlay,
    resolveAssetUrl,
    setProgress,
    setStatus,
    showError,
    strings,
  })
}

void start()
