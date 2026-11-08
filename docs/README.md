# Win2Lin documentation

This directory contains project-level documentation for Win2Lin. The user-facing overview and quick start remain in the repository [`README.md`](../README.md).

## Index

| Document | Purpose |
|---|---|
| [`../VISION.md`](../VISION.md) | Long-term direction: a universal, safe, local-first migration and environment portability assistant; principles and boundaries. |
| [`../ROADMAP.md`](../ROADMAP.md) | Phased, honest roadmap — what exists in v0.x vs what is planned (migration directions, deeper migration, UX, modules, trust, distribution). |
| [`architecture.md`](./architecture.md) | High-level architecture: current Windows exporter + Linux restore flow, portable bundle concept, and planned modules/report engine. |
| [`../README.md`](../README.md) | Current usage, safety notes, Linux support/distro behavior, and code-quality guidance. |

## Documentation principles

- **Honest status:** distinguish implemented behavior from partial scaffolding and planned work.
- **Safety first:** document secret exclusions, dry-run/preview behavior, and conservative system-mutation rules.
- **Inspectable artifacts:** prefer describing manifests, logs, and reports that users can verify locally.
- **No hype:** avoid claiming universal automation where the project provides best-effort guidance or manual steps.

## Related repository areas

These folders exist in the repo and may evolve alongside the architecture; they are not, by themselves, proof of complete features:

- `scripts/` — current Windows exporters and Linux restore helper.
- `modules/`, `specs/`, `templates/`, `data/` — scaffolding/structure for future modularization and mappings.
- `tests/`, `packaging/` — quality and distribution work areas.

When adding docs, keep them concrete, link to real files/behavior, and update [`ROADMAP.md`](../ROADMAP.md) if status changes.
