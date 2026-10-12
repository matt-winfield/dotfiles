# Global working preferences

- Use pnpm as the default JavaScript and TypeScript package manager for all projects unless a project explicitly requires another package manager.
- Use the Oxc libraries, Oxlint and Oxfmt, as the default linting and formatting tools for JavaScript and TypeScript projects.
- Configure linting to fail on warnings (for Oxlint, use `--deny-warnings` or `options.denyWarnings: true`).
- Order files top-down by dependency: exports first (after imports), dependants above their dependencies, private helpers last.
