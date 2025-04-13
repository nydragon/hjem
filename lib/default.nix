{
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault mkDerivedConfig;
  inherit (lib.options) mkOption literalExpression;
  inherit (lib.strings) hasPrefix;
  inherit (lib.types) bool submodule str path nullOr lines;
in {
  hjem = {
    mkFileType = relativeTo:
      submodule (
        {
          name,
          target,
          config,
          options,
          ...
        }: {
          options = {
            enable = mkOption {
              type = bool;
              default = true;
              example = false;
              description = ''
                Whether this file should be generated. If set to `false`, the file will
                not be created.
              '';
            };

            target = mkOption {
              type = str;
              apply = p:
                if hasPrefix config.relativeTo p
                then p
                else if !(hasPrefix "/" p)
                then "${config.relativeTo}/${p}"
                else throw "This option cannot handle absolute paths yet!";
              defaultText = "name";
              description = ''
                Path to target file relative to ${config.relativeTo}
                or absolute starting with ${config.relativeTo}.
              '';
            };

            text = mkOption {
              default = null;
              type = nullOr lines;
              description = "Text of the file";
            };

            source = mkOption {
              type = nullOr path;
              default = null;
              description = "Path of the source file or directory";
            };

            executable = mkOption {
              type = bool;
              default = false;
              example = true;
              description = ''
                Whether to set the execute bit on the target file.
              '';
            };

            clobber = mkOption {
              type = bool;
              default = config.clobberFiles;
              defaultText = literalExpression "config.hjem.clobberByDefault";
              description = ''
                Whether to "clobber" existing target paths.

                - If using the **systemd-tmpfiles** hook (Linux only), tmpfile rules
                  will be constructed with `L+` (*re*create) instead of `L`
                  (create) type while this is set to `true`.
              '';
            };

            relativeTo = mkOption {
              internal = true;
              type = path;
              default = relativeTo;
              description = "Path to which symlinks will be relative to";
              apply = x:
                assert (hasPrefix "/" x || abort "Relative path ${x} cannot be used for files.<file>.relativeTo"); x;
            };
          };

          config = {
            target = mkDefault name;
            source = mkIf (config.text != null) (
              mkDerivedConfig options.text (
                text:
                  pkgs.writeTextFile {
                    inherit name text;
                    inherit (config) executable;
                  }
              )
            );
          };
        }
      );
  };
}
