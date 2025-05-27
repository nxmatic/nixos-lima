{ parent, pkgs, system ? "aarch64-linux", enable ? false }:
parent.nixosModules.${system}
++ [ ({ ... }: { zfs-overlays.override = enable; }) ]
