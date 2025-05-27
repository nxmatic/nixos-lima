{
  nixConfig = {
    substituters = [ "https://cache.nixos.org" "https://cache.flox.dev" ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
    ];
    accept-flake-config = true;
    auto-optimise-store = true;
    trusted-users = [ "root" "@wheel" ];
    experimental-features = [ "nix-command" "flakes" ];
  };

  inputs = {
    nxmatic-flake-commons.url = "github:nxmatic/nix-flake-commons/develop";
    nixos-generators.follows = "nxmatic-flake-commons/nixos-generators";
    nixpkgs.follows = "nxmatic-flake-commons/nixpkgs";
    flake-utils.follows = "nxmatic-flake-commons/flake-utils";
    home-manager.follows = "nxmatic-flake-commons/home-manager";
    devenv.follows = "nxmatic-flake-commons/devenv";
    flox.follows = "nxmatic-flake-commons/flox";
    incus-compose.follows = "nxmatic-flake-commons/incus-compose";
    disko.follows = "nxmatic-flake-commons/disko";
    impermanence.follows = "nxmatic-flake-commons/impermanence";
  };

  outputs = { self, impermanence, disko, nixpkgs, flox, flake-utils
    , incus-compose, nixos-generators, ... }@attrs:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      baseOverlays = [
        (final: prev: {
          incus-compose = incus-compose.packages.${prev.system}.default;
          flox = flox.packages.${prev.system}.default;
        })
      ];
      zfsOverlaysModule = { ... }: { zfsOverlays.override = true; };
      nixosTailscaleTagModule = { ... }: { tailscale.tag = "nixos"; };
      mkModules = { hostModule }: [
        impermanence.nixosModules.impermanence
        disko.nixosModules.disko
        hostModule
        nixosTailscaleTagModule
        ./modules
      ];
      baseSpecialAttrs = attrs // {
        hostId = "a225c68e";
        inherit nixpkgs;
        inherit disko;
      };

      # Host logic from hosts/flake.nix, refactored as a function
      mkNixosOutputs =
        { system ? "aarch64-linux", extraModules ? [ ], zfsEnabled ? false }:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = { allowUnfree = true; };
            overlays = baseOverlays;
          };
          specialArgs = baseSpecialAttrs;
        in {
          nixosConfigurations = {
            ext4 = nixpkgs.lib.nixosSystem {
              inherit system pkgs specialArgs;
              modules = (mkModules { inherit hostModule; });
            };
            zfs = nixpkgs.lib.nixosSystem {
              inherit system pkgs specialArgs;
              modules = (mkModules { inherit hostModule; })
                ++ [ zfsOverlaysModule ];
            };
          };
          nixosDiskImage = nixos-generators.nixosGenerate {
            inherit pkgs system specialArgs;
            format = "raw-efi";
            modules = (mkModules { inherit hostModule; });
          };
        };
    in flake-utils.lib.eachSystem systems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = baseOverlays;
        };
        crossPkgs = import nixpkgs {
          inherit system;
          crossSystem = { config = "aarch64-unknown-linux-gnu"; };
          overlays = baseOverlays;
        };
        modules = [{
          nixpkgs.hostPlatform = "aarch64-linux";
          nixpkgs.buildPlatform = system;
          nixpkgs.overlays = baseOverlays;
        }] ++ (mkModules {
          hostModule = { ... }: { limaHost.enable = false; };
        });
      in {
        mkNixosOutputs = mkNixosOutputs;
        nixosModules.aarch64-linux = baseModules ++ [{
          nixpkgs.hostPlatform = "aarch64-linux";
          nixpkgs.buildPlatform = "aarch64-linux";
          nixpkgs.overlays = baseOverlays;
        }];
        nixosSpecialArgs = baseSpecialAttrs;
      });
}

