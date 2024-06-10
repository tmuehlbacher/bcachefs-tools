{ pkgs }:
let
  inherit (builtins) readDir readFile;
  inherit (pkgs.lib)
    filterAttrs
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

  # Does not create derivations with proper closures, i.e. dependencies are not
  # handled.
  mkScript =
    name:
    (pkgs.writeScript (basename name) (readFile ./${name}.sh)).overrideAttrs (old: {
      buildCommand = ''
        ${old.buildCommand}
        patchShebangs $out
      '';
    });

  mkTest = (
    script:
    pkgs.testers.runNixOSTest ({
      name = script.name;

      nodes.machine =
        { pkgs, ... }:
        {
          virtualisation.emptyDiskImages = [ 4096 ];
          boot.supportedFilesystems = [ "bcachefs" ];

          # Add any packages you need inside test scripts here
          environment.systemPackages = with pkgs; [

          ];

          environment.variables = {
            RUST_BACKTRACE = "full";
          };
        };

      testScript = ''
        machine.succeed("modprobe bcachefs")
        machine.succeed("${script}")
      '';
    })
  );

  tests = map (s: mkTest (mkScript s)) scriptNames;
in
pkgs.runCommandLocal "nixos-tests" { nativeBuildInputs = tests; } ''
  mkdir "$out"
  echo "Hurray, nixos-tests are passing!"
''
