{ pkgs }:
let
  inherit (builtins) readDir readFile;
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

  mkScript =
    name:
    (pkgs.writeScriptBin (basename name) (readFile ./${name}.sh)).overrideAttrs (old: {
      buildCommand = ''
        ${old.buildCommand}
        patchShebangs $out
      '';
    });

  mkTest = (
    script:
    let
      prelude = mkScript "prelude/simple-prelude";
    in
    pkgs.testers.runNixOSTest ({
      name = script.name;

      nodes.machine =
        { pkgs, ... }:
        {
          virtualisation.emptyDiskImages = [ 4096 ];
          boot.supportedFilesystems = [ "bcachefs" ];

          environment.systemPackages = [
            prelude
            script
          ];

          environment.variables = {
            BCACHEFS_UUID = "e9696d84-030b-4574-b169-394848b5190f";
            BLKDEV = "/dev/vdb";
            MOUNT_POINT = "/tmp/mnt";
          };
        };

      testScript = ''
        machine.succeed("udevadm settle")
        machine.succeed("simple-prelude")
        machine.succeed("udevadm settle")
        machine.succeed("${script.name}")
      '';
    })
  );
in
genAttrs scriptNames (s: mkTest (mkScript s))
