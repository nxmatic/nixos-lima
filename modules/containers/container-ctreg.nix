{ config, lib, containerRegistrySystem, ... }:

let
  containerName = "ctreg";
  pkgs = containerRegistrySystem.pkgs;
in {
  options.enableContainerRegistry = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable the container registry service.";
  };

  config = lib.mkIf config.enableContainerRegistry {
    containers."${containerName}" = {
      enableTun = true;
      ephemeral = false;
      autoStart = true;
      bindMounts = {
        "/run/tailscale/auth.key" = {
          hostPath = "/run/tailscale/auth.key";
          isReadOnly = false;
        };
      };
      allowedDevices = [{
        node = "/dev/net/tun";
        modifier = "rwm";
      }];
      config = { config, pkgs, ... }: {
        imports = [
          ./../container-host.nix
          ./../caddy.nix
          ./../docker-registry.nix
          ./../tailscale.nix
          ({ config, ... }: {
            containerHost = {
              enable = true;
              hostName = containerRegistrySystem.config.limaHost.hostName;
              guestName = containerName;
              tailscaleInterfaceName = "tailscale1";
            };
            tailscale.tags = [ "nixos" "container" ];
          })
        ];

        networking.nameservers = [ "8.8.8.8" "1.1.1.1" ];
      };
    };
  };
}
