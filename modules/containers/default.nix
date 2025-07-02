{ config, pkgs, lib, containerRegistryConfiguration, ... }: {
  imports = [
    (import ./ctreg.nix { inherit config pkgs lib containerRegistryConfiguration; })
  ];
}
