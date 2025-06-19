{
  description = "Host-specific flake for bioskop";

  inputs.parent.url = "path:../..";

  outputs = { self, parent, ... }@inputs:
    let
      system = inputs.system or "aarch64-linux";

      # NixOS Container
      mkContainerRegistrySystem = parent.mkContainerRegistrySystem.${system};
      hostModule = { ... }: {
        limaHost = {
          enable = true;
          hostName = "bioskop";
        };
      };
      containerRegistrySystem =
        mkContainerRegistrySystem { inherit system hostModule; };

      # NixOS configurations
      mkNixosOutputs = parent.mkNixosOutputs.${system};
      nixosOutputs =
        mkNixosOutputs { inherit containerRegistrySystem hostModule; };
      nixosConfiguration = nixosOutputs.nixosConfigurations.zfs;
      guestName = nixosConfiguration.config.networking.hostName;
    in {
      nixosConfigurations = nixosOutputs.nixosConfigurations // {
        ${guestName} = nixosConfiguration;
      };
      nixosDiskImage = nixosOutputs.nixosDiskImage;
    };
}
