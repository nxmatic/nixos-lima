{ lib, ... }:{
  disko = import ./config.nix { inherit lib; };
}