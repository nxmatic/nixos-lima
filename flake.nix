{
  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  inputs = {
    nxmatic-flake-commons.url = "github:nxmatic/nix-flake-commons/develop";
    nixos-generators.follows = "nxmatic-flake-commons/nixos-generators";
    nixpkgs.follows = "nxmatic-flake-commons/nixpkgs";
    flake-utils.follows = "nxmatic-flake-commons/flake-utils";
    home-manager.follows = "nxmatic-flake-commons/home-manager";
    devenv.follows = "nxmatic-flake-commons/devenv";
    flox.follows = "nxmatic-flake-commons/flox";
  };

  outputs = { self, nixpkgs, flake-utils, nixos-generators, ... }@attrs: 
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
    in
    flake-utils.lib.eachSystem systems (system:
      let
        pkgs = import nixpkgs { 
          inherit system; 
        };
        crossPkgs = import nixpkgs {
          inherit system;
          crossSystem = { config = "aarch64-unknown-linux-gnu"; };
        };
      in
      {
        packages = {
          img = nixos-generators.nixosGenerate {
            pkgs = if system == "x86_64-linux" then crossPkgs else pkgs;
            modules = [
              ./nixos.nix
              {
                nixpkgs.hostPlatform = "aarch64-linux";
                nixpkgs.buildPlatform = system;
              }
            ];
            format = "raw-efi";
          };
        };

        # Define the development shell
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.nixos-generators
            pkgs.nixos-install
            pkgs.yq-go
            pkgs.flox
          ];
        };
      }) // { 
        devShells.default = nixpkgs.mkShell {
          buildInputs = [
            nixpkgs.flox
          ];
        };
        nixosConfigurations = {
          nixos = nixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
            specialArgs = attrs;
            modules = [
              ./nixos.nix
              ./user-config.nix
            ];
          };
        };
        nixosModules = {
          lima = {
            imports = [ ./nixos.nix ];
          };
        };
      };
}
