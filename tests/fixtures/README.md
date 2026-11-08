# Test fixtures

This directory is for **synthetic, non-sensitive** fixtures used to validate Win2Lin behavior.

## Rules

- **No real secrets.** Do not add real browser credential databases, cookies, passwords, DPAPI-protected files, private keys, API tokens, cloud credentials, or personal data.
- **No personal exports.** Do not copy real `Win2Lin_export` contents into this repository.
- **Use placeholders.** Filenames/content should make intent obvious (e.g., `FAKE_LOGIN_DATA_DO_NOT_USE`, dummy certificate text that is clearly not a key).
- **Keep fixtures minimal.** Only include what is needed to exercise parsing, denylist, manifest, or restore logic.

## Intended fixture types

Examples of safe fixtures that may be added over time:

- **Denylist fixtures:** synthetic directory trees containing files named like sensitive targets (browser `Login Data`/`Cookies`/`Web Data` lookalikes, fake SSH private key names) to verify Win2Lin skips them.
- **Manifest fixtures:** expected/sanitized manifest fragments for inventory/copy reporting tests.
- **Sample export layouts:** tiny, fake `C_DRIVE`/`D_DRIVE`/config structures to test Linux restore path discovery and safe no-clobber behavior.
- **Config samples:** minimal `.gitconfig`, dot-config files, and public SSH material (`*.pub`, `known_hosts`, `authorized_keys`) that are safe to restore in tests.

## SSH/key fixture guidance

If key-related restore behavior is tested:

- Allowed in fixtures: public keys (`*.pub`), `known_hosts`, `authorized_keys`, and obviously fake placeholders.
- **Not allowed:** private keys (`id_rsa`, `id_ed25519`, PEM/OPENSSH private key blocks), password-protected key material, or anything that could be mistaken for a real credential.

## Adding new fixtures

When adding a fixture:

1. Confirm it contains no secrets or personal data.
2. Document its purpose in the fixture filename or a nearby README note if needed.
3. Reference it from `tests/README.md` or future automated tests.
4. Prefer deterministic content so future checks/manifests can be compared reliably.
