# zfs/default.nix
{ nixpkgs, disko, config, lib, pkgs, ... }:
let
  disks = {
    tank1 = "/dev/vdb";
    tank2 = "/dev/vdc";
    tank3 = "/dev/vdd";
    recover = "/dev/vde";
  };
in {
  imports = [
    (import ./disko-nixos-module.nix { inherit disko disks; })
#   (import ./zfs-nixos-module.nix { inherit disko disks config lib pkgs; })
  ];
}
