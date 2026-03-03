# How to contribute

Suggestions and contributions are welcome.

## How to suggest changes

1. **Issues** — Open an [issue](https://github.com/DinisMiranda/three_game/issues) to report a bug or propose a feature. Describe what you want to change or add.
2. **Pull requests** — If you want to contribute code or docs:
   - Fork the repository.
   - Create a branch for your change (e.g. `feat/skills-system`, `docs/update-readme`).
   - Make your changes and commit with a clear message. Prefer [Conventional Commits](https://www.conventionalcommits.org/) (e.g. `feat(battle): add skill actions`, `fix(ui): placeholder image in slots`, `docs: update architecture`).
   - Open a pull request to the `main` branch describing what you did.

## Style

- Use **English** for commit messages, PR descriptions, and new documentation.
- Keep code and docs consistent with the existing structure (see [docs/](docs/README.md)).

## CI and local checks

- **Docs** — On every push/PR, [markdownlint](https://github.com/DavidAnson/markdownlint) and [Lychee](https://github.com/lycheeverse/lychee) run on Markdown files. To lint locally: `npx markdownlint-cli2 "**/*.md" --config .markdownlint.yaml`
- **Godot** — The project is validated headless (load and quit). Run the project in Godot 4.x (F5) before pushing to catch runtime errors.

Thanks for contributing.
