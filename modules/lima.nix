{ config, pkgs, lib, ... }:
let cfg = config.lima;
in {
  options.lima.host = lib.mkOption {
    type = lib.types.str;
    default = config.networking.hostName or "default";
    description = "The name of the lima host, defaults to <hostname>.";
  };
  config = { networking.hostName = "${cfg.host}-nixos"; };
}
