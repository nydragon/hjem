# The common module that contains Hjem's per-user options. To ensure Hjem remains
# somewhat compliant with cross-platform paradigms (e.g. NixOS or Darwin.) Platform
# specific options such as nixpkgs module system or nix-darwin module system should
# be avoided here.
{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.lists) isList;
  inherit (lib.strings) concatStringsSep;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption mkEnableOption literalExpression;
  inherit (lib.types) bool str path attrsOf listOf package oneOf int;

  toEnv = env:
    if isList env
    then concatStringsSep ":" (map toString env)
    else toString env;

  mkEnvVars = vars: (concatStringsSep "\n" (mapAttrsToList (name: value: "export ${name}=\"${toEnv value}\"") vars));

  writeEnvScript = attrs: pkgs.writeShellScript "load-env" (mkEnvVars attrs);
in {
  imports = [
    # Makes "assertions" option available without having to duplicate the work
    # already done in the Nixpkgs module.
    (pkgs.path + "/nixos/modules/misc/assertions.nix")
  ];

  options = {
    enable =
      mkEnableOption "Whether to enable home management for this user"
      // {
        default = true;
      };
    user = mkOption {
      type = str;
      description = "The owner of a given home directory.";
    };

    directory = mkOption {
      type = path;
      description = ''
        The home directory for the user, to which files configured in
        {option}`hjem.users.<name>.files` will be relative to by default.
      '';
    };

    clobberFiles = mkOption {
      type = bool;
      example = true;
      description = ''
        The default override behaviour for files managed by Hjem for a
        particular user.

        A top level option exists under the Hjem module option
        {option}`hjem.clobberByDefault`. Per-file behaviour can be modified
        with {option}`hjem.users.<name>.files.<file>.clobber`.
      '';
    };

    files = mkOption {
      default = {};
      type = attrsOf (lib.hjem.mkFileType config.directory);
      example = {
        ".config/foo.txt".source = "Hello World";
      };
      description = "Files to be managed by Hjem";
    };

    packages = mkOption {
      type = listOf package;
      default = [];
      example = literalExpression "[pkgs.hello]";
      description = "Packages for ${config.user}";
    };

    environment = {
      loadEnv = mkOption {
        type = path;
        readOnly = true;
        description = ''
          A POSIX compliant shell script containing the user session variables needed to bootstrap the session.

          As there is no reliable and agnostic way of setting session variables, Hjem's
          environment module does nothing by itself. Rather, it provides a POSIX compliant shell script
          that needs to be sourced where needed.
        '';
      };
      sessionVariables = mkOption {
        type = attrsOf (oneOf [
          (listOf (oneOf [
            int
            str
            path
          ]))
          int
          str
          path
        ]);
        default = {};
        example = {
          EDITOR = "nvim";
          VISUAL = "nvim";
        };
        description = ''
          A set of environment variables used in the user environment.
          If a list of strings is used, they will be concatenated with colon
          characters.
        '';
      };
    };
  };

  config = {
    environment.loadEnv = mkIf (config.environment.sessionVariables != {}) (
      writeEnvScript config.environment.sessionVariables
    );
    assertions = [
      {
        assertion = config.user != "";
        message = "A user must be configured in 'hjem.users.<user>.name'";
      }
      {
        assertion = config.directory != "";
        message = "A home directory must be configured in 'hjem.users.<user>.directory'";
      }
    ];
  };
}
