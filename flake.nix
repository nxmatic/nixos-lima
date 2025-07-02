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
    incus-compose.follows = "darwin-home/incus-compose";
    disko.follows = "darwin-home/disko";
    impermanence.follows = "darwin-home/impermanence";
    flox.follows = "darwin-home/flox";
  };

  outputs = { self, home-manager, darwin-home, impermanence, disko, nixpkgs
    , flox, flake-utils, incus-compose, nixos-generators, ... }@inputs:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      lib = nixpkgs.lib;
      overlays = [
        (final: prev: {
          incus-compose = inputs.incus-compose.packages.${final.system}.default;
          flox = inputs.flox.packages.${final.system}.default;
        })
      ];
      zfsOverlaysModule = { ... }: { zfsOverlays.override = true; };
      nixosTailscaleTagModule = { ... }: { tailscale.tags = [ "nixos" ]; };
      darwinModule = { lib, ... }: {
        options.system.primaryUser = lib.mkOption {
          type = lib.types.str;
          description =
            "Dummy primary user option for compatibility with shared modules.";
          default = "";
        };
      };
      homeManagerModule = { config, profile, user, pkgs, lib, ... }: {
        users.users.${user.name} = {
          isNormalUser = true;
          home = toString user.home;
          shell = user.shell;
        };
        programs.zsh.enable = true;
        hm = darwin-home.homeManagerModules.manager {
          inherit config pkgs lib user self;
        };
        home-manager = {
          extraSpecialArgs = { inherit self inputs profile; };
          useGlobalPkgs = true;
          useUserPackages = true;
          verbose = true;
          backupFileExtension = "nix-backup";
        };
      };
      mkModules = { hostModule ? { ... }: { limaHost.enable = false; }
        , profileModule ? darwin-home.homeManagerModules.committed
        , system ? "x86_64-linux", overlays ? overlays, profile ? null }:
        let
          pkgs = import nixpkgs {
            inherit system overlays;
            config = { allowUnfree = true; };
          };
          user = profileModule.user or profileModule.profile.user or null;
        in [
          darwinModule
          hostModule
          profileModule
          # (homeManagerModule {
          #   inherit profile user pkgs lib self;
          #   config = self.config;
          # })
          impermanence.nixosModules.impermanence
          disko.nixosModules.disko
          nixosTailscaleTagModule
          ./modules
        ];
      specialAttrs = { containerRegistryConfiguration }:
        inputs // {
          inherit nixpkgs disko containerRegistryConfiguration;
          hostId = "a225c68e";
        };

      mkcontainerRegistryConfiguration =
        { system ? "a86_64-linux", hostModule, overlays ? overlays }:
        let pkgs = import nixpkgs { inherit overlays system; };
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
        { system ? "aarch64-linux", hostModule, containerRegistryConfiguration }:
        let
          pkgs = import nixpkgs {
            inherit overlays system;
            config = { allowUnfree = true; };
          };
          profileModule = darwin-home.homeManagerModules.profiles.committed {
            inherit pkgs lib;
          };
          specialArgs = (specialAttrs { inherit containerRegistryConfiguration; });
        in {
          nixosConfigurations = {
            ext4 = nixpkgs.lib.nixosSystem {
              inherit system pkgs specialArgs;
              modules = (mkModules {
                inherit hostModule profileModule system overlays;
              }) ++ [{
                boot.supportedFilesystems = [ "ext4" ];
                boot.kernelModules = [ "ext4" ];
              }];
            };
            zfs = nixpkgs.lib.nixosSystem {
              inherit system pkgs specialArgs;
              modules = (mkModules {
                inherit hostModule profileModule system overlays;
              }) ++ [ zfsOverlaysModule ];
            };
            containerRegistry = containerRegistryConfiguration;
          };
          nixosDiskImage = nixos-generators.nixosGenerate {
            inherit pkgs system specialArgs;
            format = "raw-efi";
            modules =
              (mkModules { inherit hostModule profileModule system overlays; });
          };
        };
    in flake-utils.lib.eachSystem systems
    (system: { inherit system mkcontainerRegistryConfiguration mkNixosOutputs; });
}
