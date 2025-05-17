{
  nixConfig = {
    substituters = [ "https://cache.nixos.org" "https://cache.flox.dev" ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
    ];
  };

  inputs = {
    nxmatic-flake-commons.url = "github:nxmatic/nix-flake-commons/develop";
    nix-snapshotter.follows = "nxmatic-flake-commons/nix-snapshotter";
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
    , incus-compose, nix-snapshotter, nixos-generators, ... }@attrs:
    let systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
    in flake-utils.lib.eachSystem systems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (final: previ: {
              # Add your custom overlays here
              flox = flox.packages.${system}.default;
              incus-compose = incus-compose.packages.${system}.default;
            })
          ];
        };
        crossPkgs = import nixpkgs {
          inherit system;
          crossSystem = { config = "aarch64-unknown-linux-gnu"; };
          overlays =
            [ (final: prev: { flox = flox.packages.${system}.default; }) ];
        };
      in {
        packages = {
          img = nixos-generators.nixosGenerate {
            pkgs = if system == "x86_64-linux" then crossPkgs else pkgs;
            modules = [
              disko.nixosModules.disko
              impermanence.nixosModules.impermanence
              ./zfs/disko-config.nix
              ./nixos.nix
              ./user-config.nix
              ./systemd/initrd.nix
              {
                nixpkgs.hostPlatform = "aarch64-linux";
                nixpkgs.buildPlatform = system;
                nixpkgs.overlays = [
                  (final: prev: {
                    incus-compose =
                      incus-compose.packages.${prev.system}.default;
                    flox = flox.packages.${prev.system}.default;
                  })
                ];
              }
            ];
            specialArgs = attrs // {
              hostId = "a225c68e";
              inherit nixpkgs;
              inherit disko;
            };
            format = "raw-efi";
          };
          nixosConfigurations = {
            nixos = nixpkgs.lib.nixosSystem {
              system = "aarch64-linux";
              specialArgs = attrs // {
                hostId = "a225c68e";
                inherit nixpkgs;
                inherit disko;
              };
              modules = [
                disko.nixosModules.disko
                impermanence.nixosModules.impermanence
                ./zfs/disko-config.nix
                ./nixos.nix
                ./user-config.nix
                {
                  nixpkgs.overlays = [
                    (final: prev: {
                      incus-compose =
                        incus-compose.packages.${prev.system}.default;
                      flox = flox.packages.${prev.system}.default;
                    })
                  ];
                }
              ];
            };
          };

          nixosModules = {
            lima = {
              imports =
                [ impermanence.nixosModules.impermanence ./nixos.nix ./zfs ];
            };
          };

        };
      });
}
