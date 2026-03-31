import { copyFile, mkdir, readdir, readFile, rm, stat, writeFile } from 'node:fs/promises'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'
import { zipSync } from 'fflate'

const websiteDir = path.resolve(fileURLToPath(new URL('..', import.meta.url)))
const rootDir = path.resolve(websiteDir, '..')
const publicDir = path.join(websiteDir, 'public')
const runtimeDir = path.join(publicDir, 'runtime')
function resolveRuntimePath(name, fallback) {
  const configuredPath = process.env[name]
  if (!configuredPath) {
    return fallback
  }
  return path.isAbsolute(configuredPath) ? configuredPath : path.resolve(rootDir, configuredPath)
}

async function ensureFile(filePath, label) {
  try {
    await stat(filePath)
  }
  catch {
    throw new Error(`Missing ${label}: ${filePath}`)
  }
}

async function collectEntries(baseDir, relativePath = '') {
  const currentDir = path.join(baseDir, relativePath)
  const entries = await readdir(currentDir, { withFileTypes: true })
  const files = []

  for (const entry of entries) {
    const nextRelativePath = path.posix.join(relativePath, entry.name)
    if (entry.isDirectory()) {
      files.push(...await collectEntries(baseDir, nextRelativePath))
    }
    else {
      const absolutePath = path.join(baseDir, nextRelativePath)
      files.push({
        data: new Uint8Array(await readFile(absolutePath)),
        path: nextRelativePath,
      })
    }
  }

  return files
}

async function buildMainArchive(outputPath) {
  const sources = ['asset', 'core', 'gameplay', 'localization', 'service', 'visual']
  const archiveEntries = {}

  for (const source of sources) {
    const files = await collectEntries(path.join(rootDir, source))
    files.forEach((file) => {
      archiveEntries[path.posix.join(source, file.path)] = file.data
    })
  }

  archiveEntries['main.game'] = new Uint8Array(await readFile(path.join(rootDir, 'main.game')))
  archiveEntries['main.lua'] = new Uint8Array(await readFile(path.join(rootDir, 'main.lua')))

  await writeFile(outputPath, zipSync(archiveEntries))
}

async function main() {
  const solunaJsPath = resolveRuntimePath('SOLUNA_JS_PATH', path.join(rootDir, 'soluna', 'bin', 'emcc', 'release', 'soluna.js'))
  const solunaWasmPath = resolveRuntimePath('SOLUNA_WASM_PATH', path.join(rootDir, 'soluna', 'bin', 'emcc', 'release', 'soluna.wasm'))
  const solunaWasmMapPath = resolveRuntimePath(
    'SOLUNA_WASM_MAP_PATH',
    path.join(rootDir, 'soluna', 'bin', 'emcc', 'release', 'soluna.wasm.map'),
  )

  await ensureFile(solunaJsPath, 'soluna.js')
  await ensureFile(solunaWasmPath, 'soluna.wasm')
  await ensureFile(path.join(publicDir, 'coi-serviceworker.min.js'), 'coi-serviceworker.min.js')
  await ensureFile(path.join(publicDir, 'fonts', 'arial.ttf'), 'arial.ttf')
  await ensureFile(path.join(publicDir, 'fonts', 'SourceHanSansSC-Regular.ttf'), 'SourceHanSansSC-Regular.ttf')

  await rm(runtimeDir, { recursive: true, force: true })
  await mkdir(runtimeDir, { recursive: true })

  await copyFile(solunaJsPath, path.join(runtimeDir, 'soluna.js'))
  await copyFile(solunaWasmPath, path.join(runtimeDir, 'soluna.wasm'))
  await buildMainArchive(path.join(runtimeDir, 'main.zip'))

  try {
    await copyFile(solunaWasmMapPath, path.join(runtimeDir, 'soluna.wasm.map'))
  }
  catch {}
}

main().catch((error) => {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`)
  process.exitCode = 1
})
