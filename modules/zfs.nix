{ config, pkgs, lib, ... }:

let

  cfg = config.zfs-overlays;

  joinMountPoints = prefix: point:
    if point == "/" then
      prefix
    else if prefix == "/" then
      point
    else
      "${prefix}${point}";

  _diskoDatasets = lib.foldl' (acc: dsAttrSet: acc // dsAttrSet) { }
    config.disko.devices._config.fileSystems.contents;

  diskoDatasets = builtins.trace ''
    -- config.diskoDatasets --
    ${builtins.toJSON _diskoDatasets}
    --'' _diskoDatasets;

  mountPoints = lib.attrNames diskoDatasets;

  _overlayMountPoints = lib.filter (mp:
    let
      ds = diskoDatasets.${mp};
      wantsOverlay = lib.elem "nixos:mount-overlay" (ds.options or [ ]);
    in wantsOverlay == "true") mountPoints;

  overlayMountPoints = builtins.trace ''
    -- config.zfs-overlays.overlayMountPoints --
    ${builtins.toJSON _overlayMountPoints}
    --'' _overlayMountPoints;

  _zfsMountPoints = lib.filter (mp:
    let
      ds = diskoDatasets.${mp};
      wantsOverlay = lib.elem "nixos:mount-overlay" (ds.options or [ ]);
    in wantsOverlay == "false") mountPoints;

  zfsMountPoints = builtins.trace ''
    -- config.zfs-overlays.zfsMountPoints --
    ${builtins.toJSON _zfsMountPoints}
    --'' _zfsMountPoints;

  ext4FileSystems = {
    # "/.ext4" = {
    #   device = "/dev/disk/by-label/nixos";
    #   fsType = "ext4";
    #   options = [ "ro" "X-mount.mkdir" ];
    # };
  };

  zfsFileSystems = lib.listToAttrs (map (mount: {
    name = "/.zfs${mount}";
    value = diskoDatasets.${mount} // {
      neededForBoot = true;
      options = [ "defaults" "X-mount.mkdir" "zfsutil" ];
    };
  }) zfsMountPoints) // lib.listToAttrs (map (mount: {
    name = "/.zfs${mount}";
    value = diskoDatasets.${mount} // {
      neededForBoot = true;
      options = [ "defaults" "X-mount.mkdir" "zfsutil" ];
    };
  }) overlayMountPoints);

  overlayFileSystems = lib.listToAttrs (map (mount: {
    name = mount;
    value = {
      fsType = "overlay";
      device = "overlay";
      neededForBoot = true;
      depends = [ "/.zfs${mount}" ];
      options = [ "defaults" "X-mount.mkdir" ];
      overlay = {
        lowerdir = [ mount ];
        upperdir = (joinMountPoints "/.zfs" mount) + "/upper";
        workdir = (joinMountPoints "/.zfs" mount) + "/workdir";
      };
    };
  }) overlayMountPoints);

  fileSystems = let
    _value = ext4FileSystems // zfsFileSystems // overlayFileSystems;
    _json = (builtins.toJSON _value);
  in (builtins.trace ''
    -- config.fileSystems --
    ${_json}
    --'' _value);

in {

  options.zfs-overlays.override = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description =
      "Whether to override fileSystems definitions at initial boot.";
  };

  config = {
    boot.loader.grub.device = "/dev/vda";
    boot.loader.timeout = 0;
    boot.zfs.devNodes = "/dev/disk/by-label";

    fileSystems = (lib.mkIf config.zfs-overlays.override
      (lib.mkMerge [ (lib.mapAttrs (_: fs: lib.mkForce fs) fileSystems) ]));

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "bootstrap-zfs" ''
        #!/usr/bin/env bash
        set -euxo pipefail

        : → mounting NixOS config
        systemctl start lima-mount-config

        : → running disko format+mount
        disko --mode format,mount /etc/nixos/modules/disko "$@"
        zpool export -a

        : → rebuilding the ZFS based system
        nixos-rebuild boot --flake /etc/nixos/bootstrap#zfs

        : → reboot the system
        zpool export -a
        # reboot
      '')
    ];

    systemd.tmpfiles.rules = [
      # ensure utmp + wtmp exist on the real root under /run
      "f /run/utmp 0664 root utmp -"
      "f /run/wtmp 0664 root utmp -"
    ];

    systemd.services.zfs-export-shutdown = {
      description = "Export all ZFS pools on shutdown";
      wantedBy = [ "poweroff.target" "reboot.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.zfs}/bin/zpool export -a";
      };
    };
  };
}
