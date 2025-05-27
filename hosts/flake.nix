{
  description = "nixos zfs system configurations";

  inputs = {
#   parent.url = "github:nxmatic/nixos-lima?ref=develop";
    parent.url = "path:..";
    nixpkgs.follows = "parent/nixpkgs";
    nixos-generators.follows = "parent/nixos-generators";
    incus-compose.follows = "parent/incus-compose";
    flox.follows = "parent/flox";
  };

  outputs = { self, parent, nixpkgs, nixos-generators, incus-compose, flox, ...
    }@inputs:
    let
      system = "aarch64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = { allowUnfree = true; };
        overlays = [
          (final: prev: {
            incus-compose = incus-compose.packages.${prev.system}.default;
            flox = flox.packages.${prev.system}.default;
          })
        ];
      };
      specialArgs = parent.nixosSpecialArgs;

      mkNixosOutputs = { extraModules ? [ ] }:
        let
          nixosSystem = { zfsEnabled }:
            nixpkgs.lib.nixosSystem {
              inherit system pkgs specialArgs;
              modules = (import ./nixos-modules.nix {
                inherit parent system pkgs;
                enable = zfsEnabled;
              }) ++ extraModules;
            };
          nixosGenerate = { format, zfsEnabled }:
            nixos-generators.nixosGenerate {
              inherit pkgs system specialArgs format;
              modules = (import ./nixos-modules.nix {
                inherit parent system pkgs;
                enable = zfsEnabled;
              }) ++ extraModules;
            };
        in {
          nixosConfigurations = {
            ext4 = nixosSystem { zfsEnabled = false; };
            zfs = nixosSystem { zfsEnabled = true; };
          };
          nixosImages = {
            bootstrap = nixosGenerate {
              format = "raw-efi";
              zfsEnabled = false;
            };
          };
        };
    in {
      inherit mkNixosOutputs;

      inherit (mkNixosOutputs { }) nixosConfigurations nixosImages;
    };
}
