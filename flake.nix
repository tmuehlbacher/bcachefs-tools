{
  description = "Userspace tools for bcachefs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
      fenix,
      crane,
      flake-compat,
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
          cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
          rustfmtToml = builtins.fromTOML (builtins.readFile ./rustfmt.toml);

          craneLib = crane.mkLib pkgs;

          commit = lib.strings.substring 0 7 (builtins.readFile ./.bcachefs_revision);

          commonArgs = {
            version = "git-${commit}";
            src = self;

            makeFlags = [
              "DESTDIR=${placeholder "out"}"
              "PREFIX="
              "VERSION=${commit}"
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

                test "$($out/bin/bcachefs version)" = "${commit}"

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

          devShells.default = pkgs.mkShell {
            inputsFrom = [
              config.packages.default
              config.treefmt.build.devShell
            ];

            LIBCLANG_PATH = "${pkgs.clang.cc.lib}/lib";

            # here go packages that aren't required for builds but are used for
            # development, and might need to be version matched with build
            # dependencies (e.g. clippy or rust-analyzer).
            packages = with pkgs; [
              cargo-audit
              cargo-outdated
              clang-tools
              clippy
              rust-analyzer
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
