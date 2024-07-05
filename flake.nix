{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell.url = "github:numtide/devshell";
  };

  outputs = inputs@{ self, flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devshell.flakeModule
      ];
      systems = [ "x86_64-linux" ];
      perSystem = { config, pkgs, system, ... }: let
        nodejs = pkgs.nodejs;
        # node2nixOutput = import ./nix { inherit pkgs nodejs system; };
        node2nixOutput = import ./nix/default.nix { 
          inherit pkgs nodejs system; 
          # Explicitly add the path to node-env.nix
          # node-env = ./nix/node-env.nix;
        };
        nodeDeps = node2nixOutput.nodeDependencies;
        app = pkgs.stdenv.mkDerivation {
          name = "eink";
          version = "0.1.0";
          src = ./.;
          buildInputs = with pkgs; [
            nodejs
            didder
          ];
          nativeBuildInputs = with pkgs; [
            pkg-config
            didder
            makeWrapper
          ];
          runtimeDependencies = with pkgs; [
            didder
          ];
          buildPhase = ''
            runHook preBuild

            export HOME=$TMPDIR
            ln -sf ${nodeDeps}/lib/node_modules ./node_modules
            export PATH="${nodeDeps}/bin:$PATH"

            npm rebuild canvas --build-from-source

            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall

            # Note: you need some sort of `mkdir` on $out for any of the following commands to work
            mkdir -p $out/bin $out/share

            # copy only whats needed for running the built app
            cp package.json $out/package.json
            cp -r libexec $out/libexec
            cp -r img.jpg $out/
            ln -sf ${nodeDeps}/lib/node_modules $out/node_modules

            cp bin/eink $out/share/eink
            chmod a+x $out/share/eink

            # Wrap the main executable and scripts
            makeWrapper $out/share/eink $out/bin/eink \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.didder pkgs.imagemagick ]}

            runHook postInstall
          '';
        };
      in {
        _module.args.pkgs = import nixpkgs {
          inherit system;
        };
        packages = {
          eink = app;
          default = app;
        };
        apps = {
          default.program = "${app}/bin/eink";
        };
        devshells.default = {
          env = [
            {
              name = "ARDUINO_BOARD";
              value = "esp32:esp32:esp32";
            }
            {
              name = "ARDUINO_PORT";
              value = "/dev/ttyACM0";
            }
            {
              name = "ARDUINO_BAUD";
              value = "115200";
            }
            {
              name = "LD_LIBRARY_PATH";
              value = pkgs.lib.makeLibraryPath [pkgs.libuuid]; 
            }
          ];
          commands = [
            {
              name = "monitor";
              help = "Monitor Arduino board";
              command = "arduino-cli monitor -p $ARDUINO_PORT -b $ARDUINO_BOARD --config baudrate=$ARDUINO_BAUD";
            }
            {
              name = "compile";
              help = "Compile Arduino sketch";
              command = "arduino-cli compile -b $ARDUINO_BOARD";
            }
            {
              name = "upload";
              help = "Upload Arduino sketch";
              command = "arduino-cli upload -b $ARDUINO_BOARD -p $ARDUINO_PORT";
            }
          ];
          packages = with pkgs; [
            node2nix
            arduino-cli
            didder
            imagemagick
          ];
        };
      };
      flake = {
        # Put your original flake attributes here.
      };
    };
}
