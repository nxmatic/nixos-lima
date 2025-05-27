{
  description = "nixos zfs system configurations";

  inputs = {
    parent.url = "path:..";
    nixpkgs.follows = "parent/nixpkgs";
    nixos-generators.follows = "parent/nixos-generators";
    incus-compose.follows = "parent/incus-compose";
    flox.follows = "parent/flox";
  };

  outputs = { self, parent, nixpkgs, nixos-generators, incus-compose, flox, ...
    }@inputs:
    let
      # Get the parent outputs
      pkgs = import nixpkgs {
        system = "aarch64-linux";
        overlays = [
          (final: prev: {
            incus-compose = incus-compose.packages.${prev.system}.default;
            flox = flox.packages.${prev.system}.default;
          })
        ];
      };
      system = "aarch64-linux";
      specialArgs = parent.nixosSpecialArgs;
      nixosSystem = overlayFileSystems:
        nixpkgs.lib.nixosSystem {
          inherit system pkgs specialArgs;
          modules = import ./zfs-filesystems-overlay.nix {
            inherit parent system pkgs;
            enable = overlayFileSystems;
          };
        };
    in let
      nixosSystemWithZfsFileSystemsOverlay = overlayFileSystems:
        nixpkgs.lib.nixosSystem {
          inherit system pkgs specialArgs;
          modules = import ./zfs-filesystems-overlay.nix {
            inherit parent system pkgs;
            enable = overlayFileSystems;
          };
        };
      nixosGenerate = { format, overlayFileSystems}:
        nixos-generators.nixosGenerate {
          inherit pkgs system specialArgs format;
          modules = import ./zfs-filesystems-overlay.nix {
            inherit parent system pkgs;
            enable = overlayFileSystems;
          };
        };
    in {
      nixosConfigurations = {
        ext4 = ( nixosSystemWithZfsFileSystemsOverlay false);
        zfs = ( nixosSystemWithZfsFileSystemsOverlay  true );
      };

      nixosImages = {
        ext4 = ( nixosGenerate {
          overlayFileSystems= false;
          format = "raw-efi";
        } );
        zfs = ( nixosGenerate {
          overlayFileSystems= false;
          format = "qcow";
        } );
      };
    };
}
