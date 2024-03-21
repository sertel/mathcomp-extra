{
  inputs = {
    nixpkgs.url        = github:nixos/nixpkgs;
    flake-utils.url    = github:numtide/flake-utils;
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      mkDrv = {
       # lib,
        coqPackages, coq
      #  , version
      } :
        let
          mathcomp = coqPackages.mathcomp;
          d = coqPackages.mkCoqDerivation {
            pname = "mathcomp-extra";
            owner = "thery";

            # Indeed how much sense does this still make?!
            # When I'm loading this library flake-style then it is already there!
            # The only thing that would make sense, would be to derive
            # the according coq and coqPackages versions!

#            inherit version;
#
#            defaultVersion = with lib.versions; lib.switch [coq.coq-version mathcomp.version] [
#              { cases = [(isGe "8.19") (isGe "2.2.0")  ]; out = "0.2.0"; }
#              { cases = [(range "8.17" "8.18") (isGe "2.1.0") ]; out = "0.1.0"; }
#            ] null;
#
#            release."0.2.0" = {
#              rev = "715b62ab9974542771ddbfecb2ea93fbcb914e6b";
#              sha256 = "";
#            };
#            release."0.1.0" = {
#              rev = "969b32d07e9bae4e0d932b968efdc03d4a637e91";
#              sha256 = "";
#            };

            propagatedBuildInputs =
              [ coq ]
              ++
              (with coqPackages; [hierarchy-builder
                                  mathcomp-ssreflect
                                  mathcomp-fingroup
                                  mathcomp-algebra
                                  mathcomp-field
                                  mathcomp-zify
                                  mathcomp-algebra-tactics
                                 ]);
            meta = {
              description = "Extra contribution for mathcomp";
              license = coqPackages.lib.licenses.mit;
            };
          };
        in
          # getting this the flake-style means the code is already there
          d.overrideAttrs (oldAttrs: {
            src = ./.;
          });
    in { inherit mkDrv; } //
       flake-utils.lib.eachDefaultSystem (system:
         let
           pkgs = nixpkgs.legacyPackages.${system};
         in
           rec {
             devShell =
               let
                 args = {
                   #inherit (pkgs) stdenv which;
                   coqPackages = pkgs.coqPackages_8_18.overrideScope
                     (self: super: {
                       mathcomp = super.mathcomp.override { version = "2.1.0"; };
                     });
                   coq = pkgs.coq_8_18;
                 };
                 mathcomp-extra = mkDrv args;
               in
                 pkgs.mkShell {
                   packages =
                     (with pkgs; [ gnumake ])
                     ++
                     (with mathcomp-extra; propagatedBuildInputs);
                 };
           });
}
