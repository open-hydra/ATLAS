import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'ATLAS',
  description: 'ATLAS – Hydra pre-processing toolchain for multi-physics simulations',
  lang: 'en-US',

  themeConfig: {
    logo: '/logo.svg',

    nav: [
      { text: 'Home',            link: '/' },
      { text: 'Getting Started', link: '/getting-started/' },
      { text: 'User Guide',      link: '/user-guide/' },
      { text: 'Tutorials',       link: '/tutorials/' },
      { text: 'Theory',          link: '/theory/' },
      { text: 'Development',     link: '/development/' },
      { text: 'API Reference',   link: '/api-reference/' },
    ],

    sidebar: {
      // ── Getting Started ──────────────────────────────────────────────
      '/getting-started/': [
        {
          text: 'Getting Started',
          items: [
            { text: 'Introduction',   link: '/getting-started/' },
            { text: 'Requirements',   link: '/getting-started/requirements' },
            { text: 'Installation',   link: '/getting-started/installation' },
            { text: 'Quick Start',    link: '/getting-started/quick-start' },
          ]
        }
      ],

      // ── User Guide ───────────────────────────────────────────────────
      '/user-guide/': [
        {
          text: 'Overview',
          items: [
            { text: 'ATLAS Tools',   link: '/user-guide/' },
          ]
        },
        {
          text: 'GPB — General Phase Builder',
          collapsed: false,
          items: [
            { text: 'Overview',           link: '/user-guide/gpb/' },
            { text: 'Input Reference',    link: '/user-guide/gpb/input-reference' },
            { text: 'Ideal Gas',          link: '/user-guide/gpb/ideal-gas' },
            { text: 'Condensed & Solid',  link: '/user-guide/gpb/condensed-solid' },
            { text: 'Real Fluid',         link: '/user-guide/gpb/real-fluid' },
            { text: 'Output Files',       link: '/user-guide/gpb/output' },
          ]
        },
        {
          text: 'BCB — Boundary Condition Builder',
          collapsed: true,
          items: [
            { text: 'Overview',        link: '/user-guide/bcb/' },
            { text: 'Input Reference', link: '/user-guide/bcb/input-reference' },
            { text: 'BC Types',        link: '/user-guide/bcb/bc-types' },
            { text: 'Output Files',    link: '/user-guide/bcb/output' },
          ]
        },
        {
          text: 'ICB — Initial Condition Builder',
          collapsed: true,
          items: [
            { text: 'Overview',        link: '/user-guide/icb/' },
            { text: 'Input Reference', link: '/user-guide/icb/input-reference' },
            { text: 'IC Strategies',   link: '/user-guide/icb/ic-strategies' },
            { text: 'Output Files',    link: '/user-guide/icb/output' },
          ]
        },
        {
          text: 'STB — Setup Tool Builder',
          collapsed: true,
          items: [
            { text: 'Overview',        link: '/user-guide/stb/' },
            { text: 'Input Reference', link: '/user-guide/stb/input-reference' },
            { text: 'Output Files',    link: '/user-guide/stb/output' },
          ]
        },
        {
          text: 'KAnT',
          collapsed: true,
          items: [
            { text: 'Overview',  link: '/user-guide/kant/' },
          ]
        },
      ],

      // ── Tutorials ────────────────────────────────────────────────────
      '/tutorials/': [
        {
          text: 'Tutorials',
          items: [{ text: 'Index', link: '/tutorials/' }]
        },
        {
          text: 'GPB Tutorials',
          collapsed: false,
          items: [
            { text: 'Overview',                    link: '/tutorials/gpb/' },
            { text: 'Fixed-property gas',          link: '/tutorials/gpb/fixed-gas' },
            { text: 'Ideal gas from Cantera',      link: '/tutorials/gpb/cantera-ideal-gas' },
            { text: 'Cantera equilibrium',         link: '/tutorials/gpb/cantera-equilibrium' },
            { text: 'CEA reactive mixture',        link: '/tutorials/gpb/cea-reactive' },
            { text: 'Heavy-gas mixture',           link: '/tutorials/gpb/heavy-gas' },
            { text: 'Condensed dispersed phase',   link: '/tutorials/gpb/condensed' },
            { text: 'Solid phase',                 link: '/tutorials/gpb/solid' },
            { text: 'Real fluid (CO₂)',            link: '/tutorials/gpb/real-fluid' },
          ]
        },
        {
          text: 'BCB Tutorials',
          collapsed: true,
          items: [
            { text: 'Overview', link: '/tutorials/bcb/' },
          ]
        },
        {
          text: 'ICB Tutorials',
          collapsed: true,
          items: [
            { text: 'Overview', link: '/tutorials/icb/' },
          ]
        },
        {
          text: 'KAnT Tutorials',
          collapsed: true,
          items: [
            { text: 'Overview', link: '/tutorials/kant/' },
          ]
        },
      ],

      // ── Theory ───────────────────────────────────────────────────────
      '/theory/': [
        {
          text: 'Theory Guide',
          items: [
            { text: 'Overview',              link: '/theory/' },
            { text: 'Thermodynamics',        link: '/theory/thermodynamics' },
            { text: 'Transport Properties',  link: '/theory/transport' },
            { text: 'Equations of State',    link: '/theory/equations-of-state' },
            { text: 'Chemical Equilibrium',  link: '/theory/chemical-equilibrium' },
          ]
        }
      ],

      // ── Development ──────────────────────────────────────────────────
      '/development/': [
        {
          text: 'Development',
          items: [
            { text: 'Overview',         link: '/development/' },
            { text: 'Project Structure', link: '/development/structure' },
            { text: 'Build System',     link: '/development/build' },
            { text: 'Testing',          link: '/development/testing' },
            { text: 'Contributing',     link: '/development/contributing' },
          ]
        },
        {
          text: 'Fortran Codebase',
          collapsed: false,
          items: [
            { text: 'Fortran Guide',       link: '/development/fortran-guide' },
            { text: 'Code Style',          link: '/development/code-style' },
            { text: 'Module Conventions',  link: '/development/fortran-modules' },
          ]
        },
        {
          text: 'Python Codebase',
          collapsed: false,
          items: [
            { text: 'Python Guide',        link: '/development/python-guide' },
            { text: 'Package Layout',      link: '/development/python-packages' },
          ]
        },
      ],

      // ── API Reference ────────────────────────────────────────────────
      '/api-reference/': [
        {
          text: 'API Reference',
          items: [
            { text: 'Overview',  link: '/api-reference/' },
          ]
        },
        {
          text: 'GPB (Python)',
          collapsed: false,
          items: [
            { text: 'Package Overview',   link: '/api-reference/gpb/' },
            { text: 'ini',                link: '/api-reference/gpb/ini' },
            { text: 'ideal_gas',          link: '/api-reference/gpb/ideal-gas' },
            { text: 'condensed',          link: '/api-reference/gpb/condensed' },
            { text: 'real_fluid',         link: '/api-reference/gpb/real-fluid' },
            { text: 'config',             link: '/api-reference/gpb/config' },
          ]
        },
        {
          text: 'BCB (Fortran)',
          collapsed: true,
          items: [
            { text: 'Module Overview',    link: '/api-reference/bcb/' },
            { text: 'Types',              link: '/api-reference/bcb/types' },
            { text: 'Builders',           link: '/api-reference/bcb/builders' },
          ]
        },
        {
          text: 'ICB (Fortran)',
          collapsed: true,
          items: [
            { text: 'Module Overview',    link: '/api-reference/icb/' },
            { text: 'Types',              link: '/api-reference/icb/types' },
            { text: 'Builders',           link: '/api-reference/icb/builders' },
          ]
        },
        {
          text: 'STB (Fortran)',
          collapsed: true,
          items: [
            { text: 'Module Overview',   link: '/api-reference/stb/' },
          ]
        },
        {
          text: 'KAnT (Python)',
          collapsed: true,
          items: [
            { text: 'Package Overview',  link: '/api-reference/kant/' },
          ]
        },
      ],
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/open-hydra/ATLAS' }
    ],

    footer: {
      message: 'Released under the MIT License',
      copyright: 'Copyright © 2024-present open-hydra contributors'
    },

    search: { provider: 'local' }
  },

  markdown: {
    lineNumbers: true,
    math: 'mathjax3',
  },

  ignoreDeadLinks: true,
})
