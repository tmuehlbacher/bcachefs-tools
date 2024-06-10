{
  description = "Userspace tools for bcachefs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-filter.url = "github:numtide/nix-filter";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      treefmt-nix,
      nix-filter,
      fenix,
      crane,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.treefmt-nix.flakeModule ];

      # can be extended, but these have proper binary cache support in nixpkgs
      # as of writing.
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      perSystem =
        {
          self',
          config,
          lib,
          pkgs,
          system,
          ...
        }:
        let
          inherit (builtins) readFile split;
          inherit (lib.lists) findFirst;
          inherit (lib.strings) hasPrefix removePrefix substring;

          cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
          rustfmtToml = builtins.fromTOML (builtins.readFile ./rustfmt.toml);

          filter = nix-filter.lib;

          craneLib = crane.mkLib pkgs;

          libbcachefsCommit = substring 0 7 (builtins.readFile ./.bcachefs_revision);
          makefileVersion = removePrefix "VERSION=" (
            findFirst (line: hasPrefix "VERSION=" line) "VERSION=0.0.0" (split "\n" (readFile ./Makefile))
          );
          version = "${makefileVersion}+git-${libbcachefsCommit}";

          commonArgs = {
            inherit version;
            src = filter {
              root = self;
              exclude = [
                "checks"
                "doc"
                "tests"
              ];
            };

            makeFlags = [
              "DESTDIR=${placeholder "out"}"
              "PREFIX="
              "VERSION=${version}"
            ];

            dontStrip = true;

            nativeBuildInputs = with pkgs; [
              pkg-config
              rustPlatform.bindgenHook
            ];

            buildInputs = with pkgs; [
              attr
              keyutils
              libaio
              libsodium
              liburcu
              libuuid
              lz4
              udev
              zlib
              zstd
            ];
          };

          cargoArtifacts = craneLib.buildDepsOnly (commonArgs // { pname = cargoToml.package.name; });
        in
        {
          packages.default = config.packages.bcachefs-tools;
          packages.bcachefs-tools = craneLib.buildPackage (
            commonArgs
            // {
              inherit cargoArtifacts;

              enableParallelBuilding = true;
              buildPhaseCargoCommand = ''
                make ''${enableParallelBuilding:+-j''${NIX_BUILD_CORES}} $makeFlags
              '';
              installPhaseCommand = ''
                make ''${enableParallelBuilding:+-j''${NIX_BUILD_CORES}} $makeFlags install
              '';

              doInstallCheck = true;
              installCheckPhase = ''
                runHook preInstallCheck

                test "$($out/bin/bcachefs version)" = "${version}"

                runHook postInstallCheck
              '';
            }
          );

          packages.bcachefs-tools-fuse = config.packages.bcachefs-tools.overrideAttrs (
            final: prev: {
              makeFlags = prev.makeFlags ++ [ "BCACHEFS_FUSE=1" ];
              buildInputs = prev.buildInputs ++ [ pkgs.fuse3 ];
            }
          );

          checks =
            let
              overlay = (final: prev: { inherit (config.packages) bcachefs-tools; });
            in
            (import ./checks { pkgs = pkgs.extend overlay; })
            // {
              cargo-clippy = craneLib.cargoClippy (
                commonArgs
                // {
                  inherit cargoArtifacts;
                  cargoClippyExtraArgs = "--all-targets -- --deny warnings";
                }
              );

              # we have to build our own `craneLib.cargoTest`
              cargo-test = craneLib.mkCargoDerivation (
                commonArgs
                // {
                  inherit cargoArtifacts;
                  doCheck = true;

                  enableParallelChecking = true;

                  pnameSuffix = "-test";
                  buildPhaseCargoCommand = "";
                  checkPhaseCargoCommand = ''
                    make ''${enableParallelChecking:+-j''${NIX_BUILD_CORES}} $makeFlags libbcachefs.a
                    cargo test --profile release -- --nocapture
                  '';
                }
              );
            };

          devShells.default = pkgs.mkShell {
            inputsFrom = [
              config.packages.default
              config.treefmt.build.devShell
            ];

            # here go packages that aren't required for builds but are used for
            # development, and might need to be version matched with build
            # dependencies (e.g. clippy or rust-analyzer).
            packages = with pkgs; [
              cargo-audit
              cargo-outdated
              clang-tools
              clippy
              rust-analyzer
              rustc
            ];
          };

          treefmt.config = {
            projectRootFile = "flake.nix";

            programs = {
              nixfmt-rfc-style.enable = true;
              rustfmt.edition = rustfmtToml.edition;
              rustfmt.enable = true;
              rustfmt.package = fenix.packages.${system}.default.rustfmt;
            };
          };
        };
    };
}
