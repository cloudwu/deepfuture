export interface SolunaRuntimeModule {
  FS: {
    mkdir: (path: string) => void
    mount: (type: unknown, options: Record<string, unknown>, mountpoint: string) => void
    syncfs: (populate: boolean, callback: (error: unknown) => void) => void
    writeFile: (path: string, data: Uint8Array, options?: { canOwn?: boolean }) => void
  }
  FS_createPath: (root: string, path: string, canRead: boolean, canWrite: boolean) => void
  IDBFS?: unknown
}

export type SolunaAppFactory = (options: Record<string, unknown>) => Promise<SolunaRuntimeModule>

export interface SolunaRuntimeFile {
  path: string
  data: Uint8Array
  canOwn?: boolean
}

export interface CreateSolunaRuntimeOptions {
  appFactory: SolunaAppFactory
  appBaseUrl: string
  arguments: string[]
  canvas: HTMLCanvasElement
  files: SolunaRuntimeFile[]
  print?: (text: string) => void
  printErr?: (text: string) => void
  onAbort?: (reason: unknown) => void
  onExit?: (status: number) => void
  onBeforeRun?: (runtimeModule: SolunaRuntimeModule) => void
}

function ensureAbsolutePath(path: string): string {
  if (!path.startsWith('/')) {
    throw new TypeError(`Expected an absolute FS path, got: ${path}`)
  }
  return path
}

function dirname(path: string): string {
  const normalized = ensureAbsolutePath(path)
  const index = normalized.lastIndexOf('/')
  return index <= 0 ? '/' : normalized.slice(0, index)
}

function ensureParentDirectory(runtimeModule: SolunaRuntimeModule, path: string): void {
  const dir = dirname(path)
  if (dir === '/') {
    return
  }
  runtimeModule.FS_createPath('/', dir.slice(1), true, true)
}

function installRuntimeFiles(runtimeModule: SolunaRuntimeModule, files: SolunaRuntimeFile[]): void {
  files.forEach((file) => {
    ensureParentDirectory(runtimeModule, file.path)
    runtimeModule.FS.writeFile(file.path, file.data, { canOwn: file.canOwn })
  })
}

export async function loadSolunaAppFactory(runtimeUrl: string): Promise<SolunaAppFactory> {
  const runtimeApi = await import(/* @vite-ignore */ runtimeUrl)
  if (typeof runtimeApi.default !== 'function') {
    throw new TypeError('soluna.js does not export createApp.')
  }
  return runtimeApi.default as SolunaAppFactory
}

export async function createSolunaRuntime(options: CreateSolunaRuntimeOptions): Promise<SolunaRuntimeModule> {
  const appBaseUrl = new URL(options.appBaseUrl, window.location.href)
  return options.appFactory({
    arguments: options.arguments,
    canvas: options.canvas,
    locateFile(path: string) {
      return new URL(path, appBaseUrl).toString()
    },
    onAbort(reason: unknown) {
      options.onAbort?.(reason)
    },
    onExit(status: number) {
      options.onExit?.(status)
    },
    preRun: [
      (runtimeModule: SolunaRuntimeModule) => {
        options.onBeforeRun?.(runtimeModule)
        installRuntimeFiles(runtimeModule, options.files)
      },
    ],
    print: options.print,
    printErr: options.printErr,
  })
}
