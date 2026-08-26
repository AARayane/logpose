{
  description = "Helium browser (imputnet), packaged from official AppImage releases — a self-updating flake input";

  # Own pin so the repo builds standalone (CI `nix build .#helium`). A consumer that
  # already has nixpkgs should set `inputs.logpose.inputs.nixpkgs.follows = "nixpkgs"`
  # to avoid pulling a second nixpkgs into its lock.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      # A flake's `packages` output bakes in THIS flake's nixpkgs config, so the
      # consumer's allowUnfree never reaches it. helium is an unfree binary-vendor
      # AppImage and is the whole point of this repo, so allow ONLY helium here —
      # the output then builds with no allowUnfree required from the consumer.
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "helium" ];
      }));
    in
    {
      packages = forAllSystems (pkgs: rec {
        helium = pkgs.callPackage ./helium.nix { };
        default = helium;
      });

      formatter = forAllSystems (pkgs: pkgs.nixpkgs-fmt);
    };
}
