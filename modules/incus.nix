{ config, pkgs, lib, user, ... }:

{
  environment.systemPackages = with pkgs; [
    incus
    incus-compose
    # incus-ui-canonical
    skopeo
  ];

  users.users.${user} = {
    extraGroups = [ "incus-admin" ];
  };

  virtualisation.incus = {
    enable = true;
    ui.enable = false;
    package = pkgs.incus; # use 'pkgs.incus' for feature releases
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
          description = "Instances on the internal network";
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
        name = "default";
        driver = "zfs";
        config = { source = "tank/nerd/incus"; };
      }];
    };
  };

  system.activationScripts.incusRootConfig = {
    text = ''
      install -d -m 0700 ~root/.config/incus
      cat > ~root/.config/incus/config.yml <<EOF
  default-remote: local
  remotes:
    docker:
      addr: https://docker.io
      protocol: oci
      public: true
  aliases: {}
  EOF
      chown root:root ~root/.config/incus/config.yml
      chmod 600 ~root/.config/incus/config.yml
    '';
  };
}