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

  # --- Recursive flattener for datasets ---
  flattenMountpoints = dsSet:
    lib.concatMap (name:
      let
        ds = dsSet.${name};
        this = if ds ? mountpoint && ds.mountpoint != null then [{
          mountpoint = ds.mountpoint;
          options = ds.options or { }; # Always an attrset
        }] else
          [ ];
        # Disko may use `children` or `datasets` for nested datasets
        children = if ds ? children then
          flattenMountpoints ds.children
        else if ds ? datasets then
          flattenMountpoints ds.datasets
        else
          [ ];
      in this ++ children) (lib.attrNames dsSet);

  # Build a mapping from mountpoint -> dataset info (including options)
  mountpointList =
    flattenMountpoints (config.disko.devices.zpool.tank.datasets or { });

  _mountpointMap = lib.listToAttrs (map (ds: {
    name = ds.mountpoint;
    value = ds;
  }) mountpointList);

  mountpointMap = builtins.trace ''
    -- mountpointMap --
    ${builtins.toJSON _mountpointMap}
    --'' _mountpointMap;

  mountPoints = lib.attrNames mountpointMap;

  _overlayMountPoints = lib.filter (mp:
    let ds = mountpointMap.${mp};
    in ds.options ? "nixos:mount-overlay" && ds.options."nixos:mount-overlay"
    == "true") mountPoints;

  overlayMountPoints = builtins.trace ''
    -- overlayMountPoints --
    ${builtins.toJSON _overlayMountPoints}
    --'' _overlayMountPoints;

  _zfsMountPoints = lib.filter (mp:
    let ds = mountpointMap.${mp};
    in !(ds.options ? "nixos:mount-overlay" && ds.options."nixos:mount-overlay"
      == "true")) mountPoints;

  zfsMountPoints = builtins.trace ''
    -- zfsMountPoints --
    ${builtins.toJSON _zfsMountPoints}
    --'' _zfsMountPoints;

  fileSystemsMap = lib.foldl' (a: b: a // b) { }
    config.disko.devices._config.fileSystems.contents;

  zfsFileSystems = lib.listToAttrs (map (mount: {
    name = "${mount}";
    value = fileSystemsMap.${mount} // {
      neededForBoot = true;
      options = [ "defaults" "X-mount.mkdir" "zfsutil" ];
    };
  }) zfsMountPoints) // lib.listToAttrs (map (mount: {
    name = "/mnt/zfs${mount}";
    value = fileSystemsMap.${mount} // {
      neededForBoot = true;
      options = [ "defaults" "X-mount.mkdir" ];
    };
  }) overlayMountPoints);

  overlayFileSystems = lib.listToAttrs (map (mount: {
    name = mount;
    value = {
      fsType = "overlay";
      device = "overlay";
      neededForBoot = true;
      depends = [ "/mnt/zfs${mount}" ];
      options = [ "defaults" ];
      overlay = {
        lowerdir = [ mount ];
        upperdir = (joinMountPoints "/mnt/zfs" mount) + "/upper";
        workdir = (joinMountPoints "/mnt/zfs" mount) + "/workdir";
      };
    };
  }) overlayMountPoints);

  fileSystems = let
    _value = zfsFileSystems // overlayFileSystems;
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
    boot = {
      loader = {
        grub.device = "/dev/vda";
        timeout = 0;
      };
      zfs = {
        forceImportRoot = false;
        devNodes = "/dev/disk/by-partlabel";
        extraPools = [ "recover" ];
      };
    };

    services.zfs = {
      autoScrub.enable = true;
      trim.enable = true;
    };

    services.sanoid = {
      enable = true;
      datasets."tank" = {
        recursive = true;
        yearly = 0;
        monthly = 0;
        weekly = 1;
        daily = 2;
        hourly = 4;
      };
    };

    fileSystems = (lib.mkIf config.zfs-overlays.override
      (lib.mkMerge [ (lib.mapAttrs (_: fs: lib.mkForce fs) fileSystems) ]));

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "bootstrap-zfs" ''
        #!/usr/bin/env bash
        set -euxo pipefail

        : → mounting NixOS config
        systemctl start nixos-mount-config

        : → running disko
        disko --mode format,mount /etc/nixos/modules/disko "$@"
        zfs umount -a

        : → setting ZFS mountpoints to legacy
        zfs list -H -o name | 
          xargs echo zfs set mountpoint=legacy |
          bash -exu -o pipefail

        : → exporting all ZFS pools
        zpool export -a

        : → booting the ZFS based system
        nixos-rebuild boot --flake /etc/nixos/bootstrap#zfs
        : systemctl reboot
      '')
    ];

    systemd.tmpfiles.rules = [
      # ensure utmp + wtmp exist on the real root under /run
      "f /run/utmp 0664 root utmp -"
      "f /run/wtmp 0664 root utmp -"
    ];

    systemd.shutdownRamfs.contents."/etc/systemd/system-shutdown/zpool".source =
      lib.mkForce (pkgs.writeShellScript "zpool-sync-export-shutdown" ''
        ${pkgs.zfs}/bin/zpool sync
        ${pkgs.zfs}/bin/zpool export -a
      '');
    systemd.shutdownRamfs.storePaths = [ "${pkgs.zfs}/bin/zpool" ];
  };
}
