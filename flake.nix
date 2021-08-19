{
  description = "Chipflasher";

  # NOTE: to be replaced by `self` if flake is adopted upstream
  inputs.chipflasher = {
    url = "git://zerocat.org/zerocat/projects/chipflasher";
    flake = false;
  };

  inputs.nixpkgs.url = "nixpkgs/nixos-21.05";
  inputs.nixpkgs-old.url = "nixpkgs/a45e68be364d751414a406bf78fadf9b60f8c606";

  outputs = { self, chipflasher, nixpkgs, nixpkgs-old }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });
      version = builtins.substring 0 8 chipflasher.lastModifiedDate;
    in
    {
      overlay = final: prev: {
        # FIXME: nixpkgs' version is too old, missing `gaf` utility
        geda = prev.geda.overrideAttrs (oa: {
          version = "1.10.2-20201222";
          src = final.fetchurl {
            url = "http://ftp.geda-project.org/geda-gaf/stable/v1.10/1.10.2/geda-gaf-1.10.2.tar.gz";
            sha256 = "sha256-6GKrJBUoU4+jvuJzkmH1aAERArYMXjmi8DWGY8BCyKQ=";
          };

          buildInputs = with final; oa.buildInputs or [ ] ++ [
            python
            groff
          ];

          nativeBuildInputs = with final; oa.nativeBuildInputs or [ ] ++ [
            fam
          ];
        });

        # Not included in later version of nixpkgs
        inherit (import nixpkgs-old { inherit (final) system; }) inkscape_0;

        # FIXME: should use a split package instead of two packages
        chipflasher-doc = with final; stdenv.mkDerivation {
          pname = "chipflasher-doc";
          inherit version;

          src = chipflasher;

          patches = [
            # The makefile expect 0.92.4, we have 0.92.5
            ./inkscape-version.patch
          ];

          buildInputs = [
            doxygen
            geda
            gerbv
            git
            gnumake
            imagemagick
            inkscape_0
            pcb
          ];

          buildPhase = ''
            make -C doc
          '';

          installPhase = ''
            mkdir -p $out/share
            mv doc/generated-documentation/ $out/share
          '';
        };

        chipflasher = with final; stdenv.mkDerivation {
          pname = "chipflasher";
          inherit version;

          src = chipflasher;

          buildInputs = [
            git
            # FIXME: needs something for `propeller-elf-gcc`
          ];

          buildPhase = ''
            make -C host/src/
          '';
        };
      };

      packages = forAllSystems (system: {
        inherit (nixpkgsFor.${system})
          chipflasher
          chipflasher-doc
          geda
          inkscape_0
          ;
      });

      defaultPackage = forAllSystems (system: self.packages.${system}.chipflasher);

      checks = forAllSystems (system: {
        inherit (self.packages.${system})
          chipflasher
          chipflasher-doc
          geda
          inkscape_0
          ;
      });
    };
}
