---
name: feedback-never-view-secret-values
description: "Never print/reveal/echo actual secret values (API keys, access keys, tokens) to terminal output, even when debugging or verifying credentials"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 267da28b-5250-47a0-84a7-f83bbbbd238b
---

Never view or print the literal value of a secret (AWS keys, API tokens, passwords, etc.) — not even to verify it's correct or non-empty.

**Why:** User finds it frustrating when secret values are revealed/echoed to the terminal or transcript, even during legitimate debugging. This applies regardless of intent.

**How to apply:** When verifying a credential exists, is non-empty, hasn't changed, or matches an expected value, use a length check or checksum/hash instead of printing it:

```bash
# Length check only:
op item get ITEM --fields "Access Key" --reveal | wc -c

# Checksum to compare without revealing:
op item get ITEM --fields "Secret Key" --reveal | sha256sum
```

Related: [[feedback_op_cli]] — secrets should flow through `op` rather than shell vars/flags in the first place, which also reduces accidental exposure.
