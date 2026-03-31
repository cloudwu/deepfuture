/// <reference types="vite/client" />

interface LocalFontData {
  blob: () => Promise<Blob>
  fullName: string
  postscriptName: string
}

interface QueryLocalFontsOptions {
  postscriptNames?: string[]
}

interface GPUAdapter {}

interface GPU {
  requestAdapter: (options?: unknown) => Promise<GPUAdapter | null>
}

interface Window {
  queryLocalFonts?: (options?: QueryLocalFontsOptions) => Promise<LocalFontData[]>
}

interface Navigator {
  gpu?: GPU
}
