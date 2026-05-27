---
name: Always use op CLI for secrets
description: User always wants secrets passed via `op run` or `op item get`, never via shell variables, read prompts, or inline flags
type: feedback
originSessionId: 4a8f0a5c-89bb-44ae-a228-fac3e3042461
---
Always use the `op` CLI to pass secrets to commands. Never suggest `read -rs`, inline `--password` flags, or shell variable workarounds.

**Why:** User had bad experience with zsh event expansion breaking special characters in passwords. More importantly, `op` is their standard and they expect it to be used everywhere without being asked.

**How to apply:** When any command needs a secret (password, token, key), use one of these patterns:

```zsh
# Inline env var injection:
MY_SECRET=op://Vault/Item/field op run -- some-command

# Env file approach for multiple secrets:
# .env: MY_SECRET=op://Vault/Item/field
op run --env-file=.env -- some-command

# Direct retrieval into a variable (when needed):
VALUE=$(op item get "Item Name" --fields fieldname --reveal)
```

Never suggest alternatives to `op` for passing credentials, even as a fallback.
