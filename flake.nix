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

      in { inherit mkDrv; } //
         rec {
           devShell =
             let
               args = {
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
