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
    flakes-commons.url = "github:nxmatic/nix-flake-commons/develop";
    darwin-home.url = "github:nxmatic/nix-darwin-home/develop";
    nixos-generators.follows = "darwin-home/nixos-generators";
    nixpkgs.follows = "darwin-home/nixpkgs";
    flake-utils.follows = "darwin-home/flake-utils";
    home-manager.follows = "darwin-home/home-manager";
    devenv.follows = "darwin-home/devenv";
    flox.follows = "darwin-home/flox";
    incus-compose.follows = "darwin-home/incus-compose";
    disko.follows = "darwin-home/disko";
    impermanence.follows = "darwin-home/impermanence";
  };

  outputs = { self, impermanence, disko, nixpkgs, flox, flake-utils
    , incus-compose, nixos-generators, ... }@attrs:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      lib = nixpkgs.lib;
      baseOverlays = [
        (final: prev: {
          incus-compose = incus-compose.packages.${prev.system}.default;
          flox = flox.packages.${prev.system}.default;
        })
      ];
      zfsOverlaysModule = { ... }: { zfsOverlays.override = true; };
      nixosTailscaleTagModule = { ... }: { tailscale.tags = [ "nixos" ]; };
      mkModules = { hostModule }: [
        impermanence.nixosModules.impermanence
        disko.nixosModules.disko
        hostModule
        nixosTailscaleTagModule
        ./modules
        nixosTailscaleTagModule
      ];
      baseSpecialAttrs = { containerRegistrySystem }:
        attrs // {
          inherit nixpkgs disko containerRegistrySystem;
          hostId = "a225c68e";
        };

      mkContainerRegistrySystem = { system ? "aarch64-linux", hostModule }:
        let pkgs = import nixpkgs { inherit system; };
        in nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          modules = [
            hostModule
            ./modules/lima-host.nix
            ./modules/container-host.nix
            ./modules/caddy.nix
            ./modules/docker-registry.nix
            ./modules/tailscale.nix
            ({ config, ... }: {
              limaHost.guestName = "ctreg";
              containerHost.hostName = config.limaHost.hostName;
            })
          ];
        };

      mkNixosOutputs =
        { system ? "aarch64-linux", hostModule, containerRegistrySystem }:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = { allowUnfree = true; };
            overlays = baseOverlays;
          };
          specialArgs = (baseSpecialAttrs { inherit containerRegistrySystem; });
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
            containerRegistry = containerRegistrySystem;
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
        inherit mkContainerRegistrySystem mkNixosOutputs;
        nixosModules.aarch64-linux = modules;
        nixosSpecialArgs = baseSpecialAttrs;
      });
}

