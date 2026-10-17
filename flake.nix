{
  description = "Helium browser (imputnet), packaged from official AppImage releases — a self-updating flake input";

  # Consumers should set inputs.logpose.inputs.nixpkgs.follows to avoid a second nixpkgs.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      # packages bakes this flake's nixpkgs config, so a consumer's allowUnfree never reaches it.
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
