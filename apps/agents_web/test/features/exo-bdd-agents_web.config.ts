import { defineConfig } from 'exo-bdd'

export default defineConfig({
  features: './**/*.feature',
  adapters: {
    browser: {
      baseURL: 'http://localhost:4000',
      headless: true,
    },
  },
})
