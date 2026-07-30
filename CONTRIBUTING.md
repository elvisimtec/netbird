# Contributing to NetBird Infrastructure

Thank you for your interest in contributing! This document outlines the process
for contributing to the NetBird infrastructure deployment project.

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Bugs in the deployment configuration, documentation, or operational tooling
should be reported via GitHub Issues.

**Before reporting a bug:**
1. Search [existing issues](https://github.com/elvisimtec/netbird/issues) to avoid duplicates
2. Check if the issue is with upstream NetBird itself ([netbirdio/netbird](https://github.com/netbirdio/netbird/issues))

**A good bug report includes:**
- Component affected (Traefik, Dashboard, Server, Proxy)
- Expected behavior vs. actual behavior
- Steps to reproduce
- Server environment (Ubuntu version, Docker version)
- Relevant log output (`docker compose logs <service>`)
- Any recent changes that might be related

### Suggesting Features

Feature requests are welcome. Use the Feature Request issue template.

**A good feature request includes:**
- The problem you're trying to solve
- Your proposed solution
- Alternatives you've considered
- Impact on existing configuration (backward compatibility)

### Documentation Improvements

Documentation fixes and improvements are always welcome and don't require
extensive justification. This includes:
- Typos, grammar fixes
- Clarifications and examples
- New troubleshooting entries
- Updated screenshots or diagrams

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Make your changes** following the conventions below
3. **Update documentation** if your change affects behavior
4. **Add a CHANGELOG entry** under `[Unreleased]`
5. **Open a pull request** with a clear description

#### PR Title Convention

Follow conventional commits format:
```
<type>: <description>
```

Types: `feat`, `fix`, `docs`, `ops`, `security`, `chore`, `refactor`

Examples:
- `feat: add Grafana dashboard for monitoring`
- `fix: correct healthcheck endpoint path`
- `docs: clarify backup procedure`

#### PR Description Template

```markdown
## What
Brief description of the change.

## Why
Why this change is needed.

## How Tested
Steps to verify the change works.

## Screenshots (if applicable)
```

## Development Conventions

### File Naming
- Markdown files: `kebab-case.md`
- Shell scripts: `kebab-case.sh`
- YAML files: `kebab-case.yml` or `.yaml`
- Environment files: `.env` extension, descriptive name

### YAML Style
- 2-space indentation
- Comments for non-obvious settings
- Sort keys logically (not alphabetically)

### Markdown Style
- One sentence per line (for better diffs)
- Code blocks with language identifiers
- Relative links to other repo files

### Shell Scripts
- `#!/bin/bash` shebang
- `set -euo pipefail` at the top
- Functions for reusable logic
- Comments explaining non-obvious operations

### Commit Messages
- Present tense ("Add feature" not "Added feature")
- First line max 72 characters
- Reference issues with `#N` or `closes #N`

## Working with Secrets

**NEVER commit secrets.** This includes:
- SSH keys
- Passwords
- API tokens
- Encryption keys
- Auth secrets

If you need to add a new secret:
1. Add it to the server's `.env` files directly
2. Add a placeholder in `.env.example`
3. Document it in `docs/configuration.md`

Use `git diff --cached` before each commit to verify no secrets are staged.

## Review Process

1. **Automated checks** must pass (CI pipeline)
2. **One maintainer approval** required for merge
3. **Documentation changes** require doc review
4. **Configuration changes** require testing evidence

## Getting Help

- **Questions:** Open a [GitHub Discussion](https://github.com/elvisimtec/netbird/discussions)
- **Bugs:** Open a [GitHub Issue](https://github.com/elvisimtec/netbird/issues)
- **Security:** See [SECURITY.md](SECURITY.md) for private reporting

## Recognition

Contributors are recognized in our release notes. All contributions — code,
documentation, bug reports, and feature suggestions — are valued.
