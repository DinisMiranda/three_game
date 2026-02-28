# Cursor AI Playbooks

Structured prompts for disciplined, evidence-first work with Cursor. The **doctrine** is already applied via [`.cursor/rules/`](../../.cursor/rules/) (always-on). Use these playbooks by **copying** them into the chat when you start a task.

## Doctrine (already active)

- **Operational doctrine** — Research first, trust code over docs, autonomous execution, professional output. See `.cursor/rules/operational-doctrine.mdc`.
- **File operations** — Use file tools for file content; use shell for system commands. See `.cursor/rules/file-operations.mdc`.

No need to paste the doctrine each time; Cursor loads project rules automatically.

## Playbooks (paste into chat)

| File | Use when |
|------|----------|
| [**request.md**](request.md) | New feature, refactor, or any planned change. Replace the first line with your goal, then paste the rest. |
| [**refresh.md**](refresh.md) | Persistent bug; simpler fixes failed. Paste with a clear description of the bug (observed vs expected, errors). |
| [**retro.md**](retro.md) | End of session. Paste to run a retrospective and optionally evolve the doctrine. |

## Optional directives (append to a playbook)

Append the **full content** of one of these to the bottom of a playbook before pasting, if you want that behaviour:

| File | Effect |
|------|--------|
| [**05-concise.md**](05-concise.md) | Maximum conciseness; no filler; lead with conclusion. |
| [**06-no-absolute-right.md**](06-no-absolute-right.md) | No sycophantic language; brief factual acknowledgments only. |

**Example:** To run a request with conciseness on: copy `request.md`, replace the first line with your goal, then paste the entire content of `05-concise.md` below it, and send.

## Typical flow

1. **Start task:** Copy `request.md` → set your objective in line 1 → paste in chat.
2. **Agent runs:** Reconnaissance → Plan → Execute → Verify → Self-audit → Report.
3. **Optional:** If you want shorter answers, include `05-concise.md` in the same paste.
4. **End session:** Paste `retro.md` so the agent can suggest doctrine updates.

For bugs that won’t go away, use `refresh.md` instead of `request.md`.

Based on [aashari/cursor-ai-prompting-rules](https://gist.github.com/aashari/07cc9c1b6c0debbeb4f4d94a3a81339e).
