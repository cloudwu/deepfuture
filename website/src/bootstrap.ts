import type { FontStatusReporter, FontStrings } from './fonts'
import { prepareFontZip } from './fonts'
import { createSolunaRuntime, loadSolunaAppFactory } from './runtime'
import { initPersistentStorage } from './storage'

export interface BootstrapStrings extends FontStrings {
  checkingWebGPU: string
  loadingMainArchive: string
  loadingRuntime: string
  mountingStorage: string
  runtimeFailedDetail: string
  runtimeFailedTitle: string
  startingRuntime: string
  webgpuMissingDetail: string
  webgpuMissingTitle: string
}

export interface BootstrapOptions {
  canvas: HTMLCanvasElement
  fontPermissionButton: HTMLButtonElement | null
  hideOverlay: () => void
  resolveAssetUrl: (path: string) => string
  setProgress: FontStatusReporter['setProgress']
  setStatus: FontStatusReporter['setStatus']
  showError: (title: string, detail: string) => void
  strings: BootstrapStrings
}

async function hasWebGPU(): Promise<boolean> {
  if (!navigator.gpu || typeof navigator.gpu.requestAdapter !== 'function') {
    return false
  }

  try {
    const adapter = await navigator.gpu.requestAdapter()
    return Boolean(adapter)
  }
  catch (error) {
    console.error('WebGPU adapter request failed', error)
    return false
  }
}

async function fetchArrayBuffer(url: string): Promise<ArrayBuffer> {
  const response = await fetch(url)
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} while fetching ${url}`)
  }
  return response.arrayBuffer()
}

export async function startApp(options: BootstrapOptions): Promise<void> {
  options.setProgress(0)
  options.setStatus(options.strings.checkingWebGPU, 5)

  if (!(await hasWebGPU())) {
    options.showError(options.strings.webgpuMissingTitle, options.strings.webgpuMissingDetail)
    return
  }

  try {
    const runtimeUrl = options.resolveAssetUrl('runtime/soluna.js')
    const runtimeBaseUrl = options.resolveAssetUrl('runtime/')

    const [appFactory, mainArchiveBuffer, fontZip] = await Promise.all([
      (async () => {
        options.setStatus(options.strings.loadingRuntime, 12)
        return loadSolunaAppFactory(runtimeUrl)
      })(),
      (async () => {
        options.setStatus(options.strings.loadingMainArchive, 24)
        return new Uint8Array(await fetchArrayBuffer(options.resolveAssetUrl('runtime/main.zip')))
      })(),
      prepareFontZip({
        fontPermissionButton: options.fontPermissionButton,
        resolveAssetUrl: options.resolveAssetUrl,
        strings: options.strings,
        ui: {
          setProgress: options.setProgress,
          setStatus: options.setStatus,
        },
      }),
    ])

    options.setStatus(options.strings.startingRuntime, 92)
    await createSolunaRuntime({
      appBaseUrl: runtimeBaseUrl,
      appFactory,
      arguments: ['zipfile=/data/main.zip:/data/font.zip'],
      canvas: options.canvas,
      files: [
        { path: '/data/main.zip', data: mainArchiveBuffer, canOwn: true },
        { path: '/data/font.zip', data: fontZip, canOwn: true },
      ],
      onAbort(reason) {
        console.error('Program aborted:', reason)
        options.showError(options.strings.runtimeFailedTitle, options.strings.runtimeFailedDetail)
      },
      onBeforeRun(runtimeModule) {
        options.setStatus(options.strings.mountingStorage, 95)
        runtimeModule.FS_createPath('/', 'data', true, true)
        initPersistentStorage(runtimeModule)
      },
      printErr: console.error,
    })

    options.setStatus(options.strings.startingRuntime, 100)
    window.setTimeout(options.hideOverlay, 400)
  }
  catch (error) {
    console.error(error)
    options.showError(
      options.strings.runtimeFailedTitle,
      error instanceof Error ? error.message : options.strings.runtimeFailedDetail,
    )
  }
}
