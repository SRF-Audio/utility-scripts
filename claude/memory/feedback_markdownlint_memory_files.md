---
name: Ignore markdownlint warnings on memory files
description: Memory files use a required frontmatter format that conflicts with markdownlint rules — ignore those warnings
type: feedback
originSessionId: 977dbd5b-a104-4965-990c-22d283213d6a
---
Memory files under `.claude/projects/*/memory/` use YAML frontmatter (`---` block before any heading) as required by the memory system format. This triggers markdownlint warnings like MD041 (first line should be h1), MD022/MD032 (blanks around headings/lists), etc.

**Why:** The frontmatter format is fixed by the memory system spec and cannot be changed to satisfy markdownlint.

**How to apply:** When the PostToolUse hook reports markdownlint warnings on files inside the `memory/` directory, ignore them — do not attempt to "fix" the memory file formatting.
