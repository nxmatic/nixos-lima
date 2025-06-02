{ pkgs, ... }:

{
  systemd.services.buildkitd = {
    description = "BuildKit Daemon";
    after = [ "network.target" "containerd.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.buildkit}/bin/buildkitd --containerd-worker=true";
      Restart = "always";
      User = "root";
    };
  };
}
