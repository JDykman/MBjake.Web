# Static Site Starter Files

This directory contains starter template files for static site projects. These files are automatically copied when you set up a new static-site project using the podman deployment template.

## Files Included

- **package.json.template** - Basic npm package configuration with build scripts
- **src/index.html.template** - Starter HTML page with modern, responsive design
- **src/style.css.template** - Professional CSS styling with gradient background
- **src/script.js.template** - Basic JavaScript functionality

## How These Files Are Used

When you run `setup.sh` with a static-site project type, these files are processed and copied to your project directory:

1. Placeholders like `{{PROJECT_NAME}}` and `{{PROJECT_DISPLAY_NAME}}` are replaced with your actual project values
2. The `.template` extension is removed
3. Files are placed in the appropriate directory structure

## Customization

After setup, you can:

- Edit `src/index.html` to modify page content
- Update `src/style.css` to change the visual design
- Add JavaScript functionality in `src/script.js`
- Modify `package.json` to add dependencies or change build scripts

## Build Process

The default build process simply copies files from `src/` to `dist/`:

```bash
npm run build
```

For more complex static sites (React, Vue, etc.), replace the build command with your framework's build command (e.g., `vite build`, `npm run build`).

