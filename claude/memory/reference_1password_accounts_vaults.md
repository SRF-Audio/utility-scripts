---
name: reference_1password_accounts_vaults
description: "Which 1Password account holds which vault — the work SSH key and Bedrock creds live in the PERSONAL account's Work vault, not the CACI account"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 732ebfcb-a523-43bf-9b37-1714494735bf
---

Two 1Password accounts are signed in:

- **Personal** — `my.1password.com` (drawthemoral@gmail.com / stephen.froeber@gmail.com). Vaults: Private, HomeLab, **Work**, Shared, Killian, Knightly, Kylie, "Stephen and Christine".
- **CACI/work** — `appliedinsight.1password.com` (stephen.froeber@caci.com). Vaults: Employee, global-source-creds, nexgen-saas-{dev,prod,stage,test}, "Products Development Team", shift-saas-{dev,prod,prodgov,stage,test}. **There is NO "Work" vault here.**

**Counterintuitive key fact:** the `Work` vault lives in the **personal** account, and it holds the work-related items:

- `GitLab CACI SSH Key` (ED25519, `R0Xgl…`) — the SSH auth key GitLab accepts; served by the 1Password SSH agent (`~/.1password/agent.sock`), pinned in `~/.config/1Password/ssh/agent.toml` as vault "Work".
- `SHIFT - Bedrock (538189757567) AWS IAM User` (item id `6cyhugp6pxj5irh2qkifnferr4`) — AWS keys that [[project_claude_dual_profile]]'s `claude-work` wrapper injects.

So anything "work" auth-wise needs the **personal** account unlocked, not the CACI one. The `claude-work` script now pins `OP_ACCOUNT=my.1password.com` so `op` never throws the account picker.

If `git pull` on a GitLab repo fails with `sign_and_send_pubkey: signing failed … agent refused operation`: the personal account (which holds the SSH key) is locked or the 1P desktop SSH agent lost client authorization — not an ssh-config problem. See [[feedback_op_cli]].
