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
    nixpkgs.url = "nixpkgs/nixos-24.11-small";
    flake-utils.url = "github:numtide/flake-utils";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, nixos-generators, ... }@attrs: 
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
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
          img = pkgs.nixos-generators.nixosGenerate {
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
          ];
        };
      }) // { 
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
