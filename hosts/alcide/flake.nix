{
  description = "Host-specific flake for alcide";

  inputs.parent.url = "path:../..";

  outputs = { self, parent, ... }@inputs:
    let
      system = inputs.system or "aarch64-linux";
      mkNixosOutputs = parent.mkNixosOutputs.${system};
      hostnameModule = { config, ... }: { lima.host = "alcide"; };
      nixosOutputs = mkNixosOutputs { extraModules = [ hostnameModule ]; };
      nixosConfiguration = nixosOutputs.nixosConfigurations.zfs;
      guestName = nixosConfiguration.config.networking.hostName;
    in {
      nixosConfigurations = nixosOutputs.nixosConfigurations // {
        ${guestName} = nixosConfiguration;
      };
      nixosDiskImage = nixosOutputs.nixosDiskImage;
    };
}
