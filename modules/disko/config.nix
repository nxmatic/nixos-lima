{ lib, disks ? {
  tank1 = "/dev/vdb";
  tank2 = "/dev/vdc";
  tank3 = "/dev/vdd";
  recover = "/dev/vde";
}, ... }:
let
  config = {
    enableConfig = false;
    devices = {
      disk = {
        tank1 = {
          type = "disk";
          device = disks.tank1;
          content = {
            type = "gpt";
            partitions = {
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "tank";
                };
              };
            };
          };
        };
        tank2 = {
          type = "disk";
          device = disks.tank2;
          content = {
            type = "gpt";
            partitions = {
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "tank";
                };
              };
            };
          };
        };
        tank3 = {
          type = "disk";
          device = disks.tank3;
          content = {
            type = "gpt";
            partitions = {
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "tank";
                };
              };
            };
          };
        };
        recover = {
          type = "disk";
          device = disks.recover;
          content = {
            type = "gpt";
            partitions = {
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "recover";
                };
              };
            };
          };
        };
      };

      zpool = {
        tank = {
          type = "zpool";
          mode = "raidz1";
          #         mountpoint = "/tank";
          rootFsOptions = {
            acltype = "posixacl";
            atime = "off";
            compression = "zstd";
            xattr = "sa";
          };
          options = { ashift = "12"; };
          datasets = {
            "nerd" = {
              type = "zfs_fs";
              #              options.mountpoint = "none";
            };
            "nerd/nix" = {
              type = "zfs_fs";
              # mountpoint = "/nix";
            };
            "nerd/var" = {
              type = "zfs_fs";
              #              options.mountpoint = "none";
            };
            "nerd/var/tmp" = {
              type = "zfs_fs";
              #              mountpoint = "/var/tmp";
            };
            "nerd/var/log" = {
              type = "zfs_fs";
              #              mountpoint = "/var/log";
            };
            "nerd/var/lib" = {
              type = "zfs_fs";
              #              options.mountpoint = "none";
            };
            "nerd/var/lib/buildkit" = {
              type = "zfs_fs";
              #              mountpoint = "/var/lib/buildkit";
            };
            "nerd/var/lib/containerd" = {
              type = "zfs_fs";
              #              mountpoint = "/var/lib/containerd";
            };
            "nerd/var/lib/incus" = {
              type = "zfs_fs";
              mountpoint = "/var/lib/incus";
            };
            "nerd/var/lib/lxc" = {
              type = "zfs_fs";
              #              mountpoint = "/var/lib/lxc";
            };
            "nerd/var/lib/nix-snapshotter" = {
              type = "zfs_fs";
              #              mountpoint = "/var/lib/nix-snapshotter";
            };
            "nerd/persist" = {
              type = "zfs_fs";
              #              mountpoint = "/persist";
              options = { "com.sun:auto-snapshot" = "false"; };
            };
          };
        };
        recover = {
          type = "zpool";
          mode = "";
          rootFsOptions = {
            acltype = "posixacl";
            atime = "off";
            compression = "zstd";
            #           mountpoint = "none";
            xattr = "sa";
          };
          options = { ashift = "12"; };
          datasets = {
            "recover" = {
              type = "zfs_fs";
              #             mountpoint = "/recover";
            };
          };
        };
      };
    };
  };

  addPostMountHook = dataset:
    if (dataset.mountpoint or (dataset.options.mountpoint or null)) != null then
      dataset // {
        postMountHook = ''
          mkdir -p "$MOUNTPOINT/workdir"
          mkdir -p "$MOUNTPOINT/upper"
        '';
      }
    else
      dataset;

  datasetsWithHooks = datasets:
    lib.mapAttrs (_: ds:
      let
        ds' = if ds ? datasets then
          ds // { datasets = datasetsWithHooks ds.datasets; }
        else
          ds;
      in addPostMountHook ds') datasets;

  zpoolWithDatasetHooks = lib.mapAttrs (poolName: pool:
    pool // {
      datasets = datasetsWithHooks (pool.datasets or { });
    }) config.devices.zpool;

  configWithDatasetsHooks = config:
    config // {
      devices = config.devices // { zpool = zpoolWithDatasetHooks; };
    };
in (configWithDatasetsHooks config)
