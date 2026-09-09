# Changelog

All notable changes to **logpose** are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) — versioning logpose's own
flake/override API, not the bundled Helium version (which each release notes explicitly).

## [Unreleased]

## [0.1.0] - 2026-09-09

### Added
- Self-updating Nix flake packaging the **Helium** browser (imputnet) from the official
  AppImage releases; a daily GitHub Action bumps the pinned version + arch hash and validates
  `nix build .#helium`. Consumed like any flake input (`nix flake update logpose`).
- `packages.helium` / `packages.default` for `x86_64-linux`.
- `allowUnfree` scoped inside the flake to **only** Helium, so a consumer needs no `allowUnfree`
  for the output.
- `helium.override { extensions = [ { id; hash; prodversion?; } … ]; }` — durable **external_crx**
  extension install: fetches the signed Web-Store CRX (pinned by hash), reads its manifest version,
  and drops an External Extension Descriptor into Helium's FHS extensions dir. No key-injection,
  no `--load-extension`.
- `commandLineArgs` override passthrough; `formatter` = `nixpkgs-fmt`.
- Bundles **Helium 0.13.6.1**.

[Unreleased]: https://github.com/AARayane/logpose/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/AARayane/logpose/releases/tag/v0.1.0
