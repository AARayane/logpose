# logpose

A tiny Nix flake that packages the [Helium](https://helium.computer) browser
(imputnet) from its official AppImage releases — and **keeps itself current**, so a
consumer can treat Helium like any other flake input instead of a special-cased,
hand-bumped package.

> The Log Pose is the compass that navigates the Grand Line. This is what your
> browser navigates the web with.

## Why this exists

Helium ships **versioned** AppImage assets with no version-less "latest" URL and
can't build from source, so it can't ride `nix flake update` at the asset level.
Without this repo, a consumer has to carry a bespoke "bump helium" script — the one
odd input that doesn't update like the rest. `logpose` moves that mechanism here: a
daily GitLab pipeline schedule (`.gitlab-ci.yml`) runs
[`update-helium.sh`](./update-helium.sh), validates the build of a new pin, and pushes
it to the protected `main` with its own deploy key. This flake's `main` then tracks upstream on its own.

## Use it

```nix
# flake.nix
inputs.logpose = {
  url = "git+ssh://git@gitlab.com/mugiwara-no-ichimi/logpose";
  inputs.nixpkgs.follows = "nixpkgs";   # dedupe: reuse your nixpkgs
};

# somewhere in your config
inputs.logpose.packages.x86_64-linux.helium
# pass Chromium flags (e.g. --load-extension=…) by overriding commandLineArgs:
inputs.logpose.packages.x86_64-linux.helium.override { commandLineArgs = "--foo"; }
```

Update it like any input: `nix flake update logpose` → rebuild. No special-casing.

## Manual bump

```sh
nix run nixpkgs#bash -- ./update-helium.sh .   # needs curl + jq + nix
```

Trust boundary: **imputnet** (the browser vendor). This flake only fetches their
signed release AppImage and wraps it with `appimageTools`. `x86_64-linux` only.
