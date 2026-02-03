// Custom esbuild configuration with Svelte support for LiveSvelte
import esbuild from "esbuild"
import sveltePlugin from "esbuild-svelte"
import sveltePreprocess from "svelte-preprocess"
import path from "path"
import { fileURLToPath } from "url"

const __dirname = path.dirname(fileURLToPath(import.meta.url))

const args = process.argv.slice(2)
const watch = args.includes("--watch")
const deploy = args.includes("--deploy")

// Define paths
const absPath = (p) => path.resolve(__dirname, p)

// Common plugins
const plugins = [
  sveltePlugin({
    preprocess: sveltePreprocess(),
    compilerOptions: {
      css: "injected",
      hydratable: true
    }
  })
]

// Build context for watching
let ctx

async function build() {
  const opts = {
    entryPoints: [absPath("js/app.js")],
    bundle: true,
    target: "es2017",
    outdir: absPath("../priv/static/assets"),
    external: ["/fonts/*", "/images/*"],
    nodePaths: [absPath("../deps")],
    loader: { ".js": "jsx" },
    plugins: plugins,
    logLevel: "info",
    minify: deploy
  }

  if (watch) {
    ctx = await esbuild.context(opts)
    await ctx.watch()
    console.log("Watching for changes...")
  } else {
    await esbuild.build(opts)
  }
}

build().catch((err) => {
  console.error(err)
  process.exit(1)
})
