{ config, pkgs, ... }: 
  let
      diskoFormat = pkgs.writeShellScriptBin "diskoFormat" "${config.system.build.diskoScript}";
  in {
  environment.systemPackages = [
    diskoFormat
  ];
  }
