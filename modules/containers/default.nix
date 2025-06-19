{ config, pkgs, lib, containerRegistrySystem, ... }: {
  imports = [
    (import ./container-ctreg.nix {
      inherit config pkgs lib containerRegistrySystem;
    })
  ];
}
