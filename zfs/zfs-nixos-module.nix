{ disko, config, disks, pkgs, lib, ... }:
let
  diskoConfig = (import ./disko-config.nix { inherit disks disko; });
  diskoConfigFile =
    pkgs.writeText "disko-config.nix" (builtins.toJSON diskoConfig);
in {
  boot.zfs.extraPools = [ "tank" "recover" ];
  boot.kernelParams = [ "console=ttyS0,115200" "console=tty1" ];

  fileSystems = {
    "/mnt/zfs-nixos" = {
      device = "tank/nerd/nixos";
      fsType = "zfs";
      options = [ "zfsutil" ];
      neededForBoot = true;
    };
    "/nix" = {
      device = "tank/nerd/nix";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };
    "/var/tmp" = {
      device = "tank/nerd/var/tmp";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };
    "/var/log" = {
      device = "tank/nerd/var/log";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };
    "/var/lib/buildkit" = {
      device = "tank/nerd/var/lib/buildkit";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };
    "/var/lib/containerd" = {
      device = "tank/nerd/var/lib/containerd";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };
    "/var/lib/incus" = {
      device = "tank/nerd/var/lib/incus";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };
    "/var/lib/lxc" = {
      device = "tank/nerd/var/lib/lxc";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };
    "/var/lib/nix-snapshotter" = {
      device = "tank/nerd/var/lib/nix-snapshotter";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };
  };
}
