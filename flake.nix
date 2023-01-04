{
  description = "github.com/mstone/rust-macro-bug";

  inputs.crane.url = "github:ipetkov/crane";
  inputs.crane.inputs.nixpkgs.follows = "nixpkgs";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.nixpkgs.url = "nixpkgs/nixpkgs-unstable";

  inputs.rust-overlay.url = "github:oxalica/rust-overlay";
  inputs.rust-overlay.inputs.flake-utils.follows = "flake-utils";
  inputs.rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

  outputs = {self, nixpkgs, crane, rust-overlay, flake-utils}:
    flake-utils.lib.simpleFlake {
      inherit self nixpkgs;
      name = "rust_macro_bug";
      preOverlays = [ 
        rust-overlay.overlays.default
      ];
      overlay = final: prev: {
        rust_macro_bug = rec {

          rust_macro_bugVersion = "0.1";
          rust_macro_bug = lib.rust_macro_bug { isShell = false; };
          devShell = lib.rust_macro_bug { isShell = true; };
          defaultPackage = rust_macro_bug;

          bintools = prev.bintools.overrideAttrs (old: {
            postFixup = 
              if prev.stdenv.isDarwin then 
                builtins.replaceStrings ["-no_uuid"] [""] old.postFixup
              else 
                old.postFixup;
          });

          cc = prev.stdenv.cc.overrideAttrs (old: {
            inherit bintools;
          });

          stdenv = prev.overrideCC prev.stdenv cc;

          # rust from rust-overlay adds stdenv.cc to propagatedBuildInputs 
          # and depsHostHostPropagated; therefore, to ensure that the correct
          # cc is present in downstream consumers, we need to override both these 
          # attrs.
          rust = with final; with pkgs; 
            #(rust-bin.stable.latest.minimal.override { targets = [ "wasm32-unknown-unknown" ]; })
            #(rust-bin.nightly.latest.minimal.override { extensions = [ "rustfmt" ]; targets = [ "wasm32-unknown-unknown" ]; })
            (rust-bin.selectLatestNightlyWith (toolchain: toolchain.minimal.override {
              extensions = [ "rustfmt" ];
              targets = [ "wasm32-unknown-unknown" ];
            })).overrideAttrs (old: {
              inherit stdenv;
              propagatedBuildInputs = [ stdenv.cc ];
              depsHostHostPropagated = [ stdenv.cc ];
            });

          # crane provides a buildPackage helper that calls stdenv.mkDerivation
          # which provides a default builder that sources a "setup" file defined
          # by the stdenv itself (passed as the environment variable "stdenv" that 
          # in turn defines a defaultNativeBuildInputs variable that gets added to 
          # PATH via the genericBuild initialization code. Therefore, we override
          # crane's stdenv to use our modified cc-wrapper. Then, we override
          # cargo, clippy, rustc, and rustfmt, similar to the newly introduced 
          # crane.lib.overrideToolchain helper.
          cranelib = crane.lib.${final.system}.overrideScope' (final: prev: {
            inherit stdenv;
            cargo = rust;
            clippy = rust;
            rustc = rust;
            rustfmt = rust;
          });

          tex = with final; with pkgs; texlive.combined.scheme-full;

          lib.rust_macro_bug = { isShell, isWasm ? false, subpkg ? "rust_macro_bug", subdir ? "." }: 
            let 
              buildInputs = with final; with pkgs; [
                rust
              ] ++ final.lib.optionals isShell [
                entr
                cargo-expand
                rustfmt
              ] ++ final.lib.optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [
              ]) ++ final.lib.optionals stdenv.isLinux ([
              ]);
            in with final; with pkgs; cranelib.buildPackage {
              pname = "${subpkg}";
              version = rust_macro_bugVersion;

              src = cranelib.cleanCargoSource ./.;

              cargoArtifacts = cranelib.buildDepsOnly {
                inherit buildInputs;
                src = cranelib.cleanCargoSource ./.;
                cargoCheckCommand = if isWasm then "" else "cargo check";
                cargoBuildCommand = if isWasm then "cargo build --release -p depict-web --target wasm32-unknown-unknown" else "cargo build --release";
                doCheck = false;
              };

              inherit buildInputs;

              cargoExtraArgs = if isWasm then "--target wasm32-unknown-unknown -p ${subpkg}" else "-p ${subpkg}"; 

              doCheck = false;
          };
        };
      };
    };
}
