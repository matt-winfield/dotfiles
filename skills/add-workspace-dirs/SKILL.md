---
name: add-workspace-dirs
description: >-
  Prints /add-dir lines for folders in a VS Code or Cursor .code-workspace
  file that are not already roots of the current session. Use when the user
  drops, attaches, or names a .code-workspace file and wants those directories
  added in Cursor or Claude Code, including when that file is the whole request.
---

# Add workspace directories

Print the `/add-dir` lines for a `.code-workspace` file. The same lines work in the Cursor agent CLI and in Claude Code. One directory per line. Do not quote the path.

Neither agent can run `/add-dir` itself. Do not execute the lines, do not start a new agent, and do not run `cursor --add`.

## Steps

1. Take the `.code-workspace` path from the user. Relative folder paths inside the file are resolved from that file's directory. If you only have the file contents, ask for its path.
2. Collect every directory that is already a root of this session, including the current workspace and any extra roots in your instructions.
3. Run the script from the session's working directory. Repeat `--have` once per extra root. The script also treats its own current working directory as already added.

```bash
node ~/dotfiles/skills/add-workspace-dirs/scripts/print-add-dir.mjs \
  "/path/to/file.code-workspace" \
  --have "/already/added"
```

4. From the script output, reply with every line that starts with `/add-dir`, unchanged and before any other text. Then mention the rest:
   - `already:` directories are already in this session.
   - `missing:` paths do not exist. Do not invent a command for them.
5. If there are no `/add-dir` lines, say that every existing folder is already in the session.
