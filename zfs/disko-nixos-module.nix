# zfs-disko.nix
{ disko, disks, pkgs, ... }:
{
  imports = [
    disko.nixosModules.disko
    (pkgs.callPackage ./disko-config.nix { inherit disks; })
  ];
}
