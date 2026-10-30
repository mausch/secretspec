{
  description = "SecretSpec — declarative secrets for every environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.crane.url = "github:ipetkov/crane";
  outputs = { self, nixpkgs, crane }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          craneLib = crane.mkLib pkgs;
          secretspec = craneLib.buildPackage {
            pname = "secretspec";
            version = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).workspace.package.version;
            # Tests use shell fixtures and other non-Rust files from the repository.
            src = self;
            cargoExtraArgs = "-p secretspec";
            nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config ];
            nativeCheckInputs = [ pkgs.gitMinimal pkgs.jq pkgs.sops ];
            preCheck = ''
              export HOME="$TMPDIR"
              export NO_COLOR=1
              export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              patchShebangs secretspec/tests/fixtures
            '';
            meta.mainProgram = "secretspec";
          };
        in {
          inherit secretspec;
          default = secretspec;
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/secretspec";
        };
      });

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = [ self.packages.${system}.default ];
        };
      });
    };
}
