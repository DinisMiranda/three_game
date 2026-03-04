# CI/CD workflows

## Branch flow

- **develop** — development; PRs from feature branches target `develop`.
- **staging** — pre-production; merge `develop` → `staging` when ready for staging.
- **main** — production; merge `staging` → `main` for release.

## Workflows

| Workflow | Triggers | Purpose |
|----------|----------|---------|
| **CI** (`ci.yml`) | Push/PR on `develop`, `staging`, `main` | **Branch flow:** blocks PRs in the wrong direction (allows only staging→main, develop→staging, feature→develop). Docs (markdown lint + link check), Godot project validation. |
| **CD** (`cd.yml`) | Push to `staging`, `main` | Deploy staging on push to `staging`; deploy production on push to `main`. Add your export/deploy steps (e.g. Godot export, itch.io, artifacts) in the workflow. |

## GitHub setup

1. **Create branches:** In the repo, create `develop` and `staging` (e.g. from current `main`: create branch `develop`, then create `staging` from `develop` or `main`).
2. **Default branch:** Optionally set `develop` as default so new PRs target it.
3. **Branch protection (optional):**
   - `main`: require PR, require status checks (CI), no direct push.
   - `staging`: require PR from `develop`, require CI.
   - `develop`: require PR from feature branches, require CI.

After that, merge only in order: feature → develop → staging → main.
