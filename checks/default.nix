{ pkgs }:
let
  inherit (builtins) readDir;
  inherit (pkgs.lib)
    filterAttrs
    genAttrs
    hasSuffix
    lists
    mapAttrsToList
    removeSuffix
    splitString
    ;

  basename = path: (lists.last (splitString "/" path));
  scriptName = shFile: removeSuffix ".sh" (basename shFile);

  scriptNames = mapAttrsToList (n: v: scriptName n) (
    filterAttrs (n: v: v == "regular" && hasSuffix ".sh" n) (readDir ./.)
  );

  mkTest =
    name:
    pkgs.testers.runNixOSTest {
      inherit name;

      nodes.machine =
        { pkgs, ... }:
        {
          virtualisation.emptyDiskImages = [ 4096 ];
          boot.supportedFilesystems = [ "bcachefs" ];
          boot.kernelPackages = pkgs.linuxPackages_latest;

          # Add any packages you need inside test scripts here
          environment.systemPackages = with pkgs; [
            genpass
            keyutils
          ];

          environment.variables = {
            RUST_BACKTRACE = "full";
          };
        };

      testScript = ''
        machine.succeed("modprobe bcachefs")
        machine.succeed("${./${name}.sh} 1>&2")
      '';
    };
in
genAttrs scriptNames mkTest
