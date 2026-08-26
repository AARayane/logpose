{
  description = "Helium browser (imputnet), packaged from official AppImage releases — a self-updating flake input";

  # Own pin so the repo builds standalone (CI `nix build .#helium`). A consumer that
  # already has nixpkgs should set `inputs.logpose.inputs.nixpkgs.follows = "nixpkgs"`
  # to avoid pulling a second nixpkgs into its lock.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        helium = pkgs.callPackage ./helium.nix { };
        default = helium;
      });

      formatter = forAllSystems (pkgs: pkgs.nixpkgs-fmt);
    };
}
