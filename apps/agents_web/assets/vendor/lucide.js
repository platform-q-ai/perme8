const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = plugin(function({matchComponents, theme}) {
  let iconsDir = path.join(__dirname, "../node_modules/lucide-static/icons")
  let values = {}

  // Read all SVG files from lucide-static icons directory
  fs.readdirSync(iconsDir).forEach(file => {
    if (file.endsWith('.svg')) {
      let name = path.basename(file, ".svg")
      values[name] = {name, fullPath: path.join(iconsDir, file)}
    }
  })

  matchComponents({
    "lucide": ({name, fullPath}) => {
      let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
      content = encodeURIComponent(content)
      let size = theme("spacing.6")

      return {
        [`--lucide-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
        "-webkit-mask": `var(--lucide-${name})`,
        "mask": `var(--lucide-${name})`,
        "mask-repeat": "no-repeat",
        "background-color": "currentColor",
        "vertical-align": "middle",
        "display": "inline-block",
        "width": size,
        "height": size
      }
    }
  }, {values})
})
