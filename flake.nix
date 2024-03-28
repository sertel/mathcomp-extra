{
  inputs = {
    nixpkgs.url        = github:nixos/nixpkgs;
    flake-utils.url    = github:numtide/flake-utils;
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        mkDrv = { coqPackages, coq, version } :
          let
            mathcomp = coqPackages.mathcomp;
            d = coqPackages.mkCoqDerivation {
              pname = "mathcomp-extra";
              owner = "thery";
              inherit version;

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

        mkDrv' = { mce_revision } :
          let
            release."0.2.0" = {
              rev = "715b62ab9974542771ddbfecb2ea93fbcb914e6b";
              deps = {
                version = "0.2.0";
                coq = pkgs.coq_8_19;
                coqPackages = pkgs.coqPackages_8_19.overrideScope
                  (self: super: {
                    mathcomp = super.mathcomp.override { version = "2.2.0"; };
                  });
              };
            };
            release."0.1.0" = {
              rev = "969b32d07e9bae4e0d932b968efdc03d4a637e91";
              deps = {
                version = "0.1.0";
                coq = pkgs.coq_8_18;
                coqPackages = pkgs.coqPackages_8_18.overrideScope
                  (self: super: {
                    mathcomp = super.mathcomp.override { version = "2.1.0"; };
                  });
              };
            };
            deps = with pkgs.coqPackages.lib; switch mce_revision [
              { case = {r}: release."0.2.0".rev == r; out = release."0.2.0".deps; }
              { case = {r}: release."0.1.0".rev == r; out = release."0.1.0".deps; }
            ] null;
          in
            mkDrv (with deps; { inherit coq coqPackages version; } );

      in { inherit mkDrv mkDrv'; } //
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
               mathcomp-extra = mkDrv args "0.1.0";
             in
               pkgs.mkShell {
                 packages =
                   (with pkgs; [ gnumake ])
                   ++
                   (with mathcomp-extra; propagatedBuildInputs);
               };
         });
}
