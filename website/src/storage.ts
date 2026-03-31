import type { SolunaRuntimeModule } from './runtime'

export function initPersistentStorage(runtimeModule: SolunaRuntimeModule): void {
  if (!runtimeModule.IDBFS) {
    return
  }

  try {
    runtimeModule.FS.mkdir('/persistent')
  }
  catch (error) {
    if (!String(error).includes('File exists')) {
      console.warn('Failed to create /persistent', error)
    }
  }

  try {
    runtimeModule.FS.mount(runtimeModule.IDBFS, { autoPersist: true }, '/persistent')
    runtimeModule.FS.syncfs(true, (error) => {
      if (error) {
        console.error('Failed to sync from IDBFS', error)
      }
    })
  }
  catch (error) {
    console.warn('Failed to init persistent storage', error)
  }
}
