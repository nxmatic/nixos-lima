{ config, pkgs, lib, user, ... }:

{
  environment.systemPackages = with pkgs; [
    incus
    incus-compose
  ];

  users.users.${user} = {
    extraGroups = [ "incus-admin" ];
  };

  virtualisation.incus = {
    enable = true;
    ui.enable = false;
    package = pkgs.incus-lts; # use 'pkgs.incus' for feature releases
    preseed = {
      networks = [{
        name = "internalbr0";
        type = "bridge";
        description = "Internal/NATted bridge";
        config = {
          "ipv4.address" = "auto";
          "ipv4.nat" = "true";
          "ipv6.address" = "auto";
          "ipv6.nat" = "true";
        };
      }];
      profiles = [
        {
          name = "default";
          description = "Default Incus Profile";
          devices = {
            eth0 = {
              name = "eth0";
              network = "internalbr0";
              type = "nic";
            };
            root = {
              path = "/";
              pool = "default";
              type = "disk";
            };
          };
        }
        {
          name = "bridged";
          description = "Instances bridged to LAN";
          devices = {
            eth0 = {
              name = "eth0";
              nictype = "bridged";
              parent = "externalbr0";
              type = "nic";
            };
            root = {
              path = "/";
              pool = "default";
              type = "disk";
            };
          };
        }
      ];
      storage_pools = [{
        name = "nerd";
        driver = "zfs";
        config = { source = "tank/nerd/incus"; };
      }];
    };
  };
}