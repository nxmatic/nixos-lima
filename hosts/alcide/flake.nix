{
  description = "Host-specific flake for alcide";

  inputs.parent.url = "path:../..";

  outputs = { self, parent, ... }@inputs:
    let
      system = inputs.system or "aarch64-linux";

      # NixOS Container
      mkcontainerRegistryConfiguration = parent.mkcontainerRegistryConfiguration.${system};
      hostModule = { ... }: {
        limaHost = {
          enable = true;
          hostName = "alcide";
        };
      };
      containerRegistryConfiguration =
        mkcontainerRegistryConfiguration { inherit system hostModule; };

      # NixOS configurations
      mkNixosOutputs = parent.mkNixosOutputs.${system};
      nixosOutputs =
        mkNixosOutputs { inherit containerRegistryConfiguration hostModule; };
      nixosConfiguration = nixosOutputs.nixosConfigurations.zfs;
      guestName = nixosConfiguration.config.networking.hostName;
    in {
      nixosConfigurations = nixosOutputs.nixosConfigurations // {
        ${guestName} = nixosConfiguration;
      };
      nixosDiskImage = nixosOutputs.nixosDiskImage;
    };
}
