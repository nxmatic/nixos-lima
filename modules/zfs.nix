{ config, lib, ... }:

let

  cfg = config.zfs-overlays;

  joinMountPoints = prefix: point:
    if point == "/" then
      prefix
    else if prefix == "/" then
      point
    else
      "${prefix}${point}";

  # Merge the list of singleton sets into one attribute set
  diskoFileSystems = lib.foldl' (a: b: a // b) { }
    config.disko.devices._config.fileSystems.contents;
  mountPoints = let value = lib.attrNames diskoFileSystems;
  in builtins.trace ''
    -- config.disko.devices._config.fileSystems.contents --
    ${builtins.toJSON value}
    --'' value;

  ext4FileSystems = {
    # "/.ext4" = {
    #   device = "/dev/disk/by-label/nixos";
    #   fsType = "ext4";
    #   options = [ "ro" "X-mount.mkdir" ];
    # };
  };

  zfsFileSystems = lib.listToAttrs (map (mount: {
    name = "legacy";
    value = diskoFileSystems.${mount};
  }) mountPoints);

  overlayFileSystems = lib.listToAttrs (map (mount: {
    name = mount;
    value = {
      fsType = "overlay";
      device = "overlay";
      options = [
        "lowerdir=${(joinMountPoints "/" mount)}"
        "upperdir=${(joinMountPoints "/.zfs" mount)}/upper"
        "workdir=${(joinMountPoints "/.zfs" mount)}/workdir"
        "X-mount.mkdir"
      ];
    };
  }) mountPoints);

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
  };
}
