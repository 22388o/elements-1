{ nixpkgs ? import <nixpkgs> {}
, ghc ? "ghc8107"
, coqPackages ? "coqPackages_8_14"
, secp256k1git ? null
}:
let hp = nixpkgs.haskell.packages.${ghc};
    cp = nixpkgs.${coqPackages};
 in rec
{
  haskell = haskellPackages.callPackage ./Simplicity.Haskell.nix {};

  haskellPackages = hp.override {
    overrides = self: super: {
      Simplicity = haskell;
    };
  };

  coq = nixpkgs.callPackage ./Simplicity.Coq.nix {
    inherit (cp) coq;
    inherit vst;
  };

  c = nixpkgs.callPackage ./Simplicity.C.nix {};

  compcert = nixpkgs.callPackage ./compcert-opensource.nix {
    inherit (cp) coq flocq;
    inherit (cp.coq.ocamlPackages) ocaml menhir menhirLib findlib;
    ccomp-platform = "x86_64-linux";
  };

  vst = nixpkgs.callPackage ./vst.nix {
    inherit (cp) coq;
    inherit compcert;
  };

  # $ nix-build -A inheritance -o inheritance.Coq.eps
  inheritance = nixpkgs.runCommand "inheritance.Coq.eps" { buildInputs = [ nixpkgs.graphviz ]; } "dot ${./inheritance.Coq.dot} -Teps -o $out";

  # build the object file needed by Haskell's Simplicity.LibSecp256k1.FFI module
  # e.g. $ nix-build --arg secp256k1git ~/secp256k1 -A mylibsecp256k1 -o libsecp256k1.o
  mylibsecp256k1 = nixpkgs.callPackage ./mylibsecp256k1.nix {
    inherit secp256k1git;
  };
}
