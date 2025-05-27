{ parent, pkgs, system ? "aarch64-linux", enable ? false }:
parent.nixosModules.${system}
++ [ ({ ... }: { zfsOverlays.override = enable; }) ]
