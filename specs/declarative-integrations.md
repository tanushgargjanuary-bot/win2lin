# Declarative & dotfile integrations (spec draft)

**Status:** draft  
**Scope:** bridge Win2Lin bundles with tools users trust (dotfiles, chezmoi/yadm, devbox, Nix/Home Manager, Ansible user-level).

## Goals
- Detect safe dotfiles/config and propose export into existing workflows.
- Generate **reviewable drafts/patches/snippets** (not silent rewrites).
- Map developer environment intent (tools, versions, config) into reproducible manifests and manual/declarative next steps.

## Safety
- **No automatic NixOS rebuild, Home Manager switch, Guix system reconfigure, or equivalent system mutation** by default.
- Generated declarative config is a **draft artifact requiring user review**.
- **Never place secrets** in generated config, env files, or “convenience” templates.
- Respect immutable/atomic/transactional/managed systems; prefer user-level/profile-scoped outputs.

## Integrations (planned)
- Dotfiles: git repo layout suggestions, chezmoi/yadm mapping hints.
- Dev: `mise`/`asdf`/`devbox` intent manifests.
- Nix/Home Manager: draft modules/snippets only.
- Containers: `distrobox`/toolbox recipes (guidance) for app compatibility.
