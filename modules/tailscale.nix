{ config, pkgs, lib, ... }:
let
  cfg = config.tailscale;
  tailscaleKey = ./tailscale.key;
  tagsString = lib.concatStringsSep "," (map (tag: "tag:" + tag) cfg.tags);
in {
  config = {
    systemd.tmpfiles.rules =
      [ "L /run/tailscale/auth.key - root root - ${tailscaleKey}" ];

    services.tailscale = {
      enable = true;
      authKeyFile = "/run/tailscale/auth.key";
      useRoutingFeatures = "both";
      extraUpFlags = [
        "--ssh"
        "--advertise-tags=${tagsString}"
        "--hostname=${config.networking.hostName}"
      ];
    };
  };
  options.tailscale = {
    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "nixos" ];
      description = "Tags to use for the Tailscale node, defaults to ['nixos'].";
    };
  };
}
