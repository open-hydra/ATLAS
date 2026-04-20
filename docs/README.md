# ATLAS Documentation

Complete documentation site for ATLAS project using VitePress.

## Overview

This directory contains the source markdown files and configuration for the ATLAS documentation website built with [VitePress](https://vitepress.dev/).

## Directory Structure

```
docs/
├── .vitepress/
│   ├── config.ts          # VitePress configuration
│   └── theme/             # Theme customization (optional)
├── index.md               # Home page
├── faq.md                 # Frequently asked questions
├── troubleshooting.md     # Troubleshooting guide
│
├── getting-started/       # Getting started section
│   ├── index.md
│   ├── requirements.md
│   ├── installation.md
│   └── quick-start.md
│
├── user-guide/            # User guide section
│   ├── index.md
│   ├── configuration.md
│   ├── running.md
│   ├── input-files.md
│   ├── output-files.md
│   └── examples.md
│
├── development/           # Development section
│   ├── index.md
│   ├── build.md
│   ├── structure.md
│   ├── contributing.md
│   ├── testing.md
│   └── code-style.md
│
├── api-reference/         # API reference section
│   ├── index.md
│   ├── modules.md
│   ├── data-types.md
│   ├── subroutines.md
│   └── functions.md
│
└── package.json           # Node.js dependencies
```

## Getting Started

### Prerequisites

- Node.js 16+ (for running VitePress)
- npm or yarn

### Installation

```bash
# Install dependencies
npm install

# Or with yarn
yarn install
```

### Development Server

Start the local development server:

```bash
npm run docs:dev
```

The documentation will be available at `http://localhost:5173`

### Building

Generate the static site:

```bash
npm run docs:build
```

Output will be in `.vitepress/dist/`

### Preview

Preview the built site:

```bash
npm run docs:preview
```

## Content Management

### Adding New Pages

1. Create a `.md` file in the appropriate directory
2. Add it to the sidebar configuration in `.vitepress/config.ts`
3. Use relative links to other pages: `[Link Text](./other-page)`

### Page Structure

Each page should start with a level-1 heading:

```markdown
# Page Title

Content here...

## Section 1

Subsection content...

## Section 2

More content...
```

### Internal Links

Link to other pages using relative paths:

```markdown
- [Getting Started](/getting-started/)
- [Installation Guide](./installation)
- [Contributing](../development/contributing)
```

### Code Blocks

Fortran:
```markdown
\`\`\`fortran
program hello
  print *, "Hello, world!"
end program hello
\`\`\`
```

Bash:
```markdown
\`\`\`bash
cd ATLAS
mkdir build
cd build
cmake ..
make
\`\`\`
```

## Configuration

Edit `.vitepress/config.ts` to:
- Change site title and description
- Modify navigation menu
- Update sidebar structure
- Customize theme colors
- Add social links

## Styling

VitePress uses Vue and provides built-in styling. Custom styles can be added in:
- `.vitepress/theme/custom.css`
- Individual page styles with `<style>` blocks

## Deployment

### Static Site Hosting

After building, the `docs/.vitepress/dist/` directory can be deployed to:
- GitHub Pages
- Netlify
- Vercel
- Any static host

### Example: GitHub Pages

```bash
# Build
npm run docs:build

# Commit and push dist folder to gh-pages branch
git add docs/.vitepress/dist/
git commit -m "docs: update site"
git push
```

## TODO Items

Throughout the documentation, sections marked with "TODO:" indicate content that needs to be filled in:

1. **Project Overview**: Add comprehensive project description
2. **System Requirements**: Document minimum requirements
3. **Installation**: Complete installation instructions
4. **API Documentation**: Add detailed Fortran API docs
5. **Examples**: Add working code examples
6. **Images/Diagrams**: Add visual aids where helpful

### Finding TODOs

```bash
grep -r "TODO:" . --include="*.md"
```

## Contributing to Docs

When adding content:

1. Follow the markdown style used in existing files
2. Keep line length reasonable (80-120 chars)
3. Use clear, concise language
4. Include code examples where appropriate
5. Add links to related pages
6. Run locally to verify formatting

## Resources

- [VitePress Documentation](https://vitepress.dev/)
- [Markdown Guide](https://www.markdownguide.org/)
- [ATLAS Repository](https://github.com/open-hydra/ATLAS)

## License

Documentation is typically under the same license as the code. See LICENSE file in root.

---

**Need help?** See [Troubleshooting](/troubleshooting) or check the [VitePress docs](https://vitepress.dev/).
