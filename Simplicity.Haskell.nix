{ mkDerivation, base, binary, cereal, lens-family, lib, MemoTrie, mtl, QuickCheck, stdenv, split, tasty, tasty-hunit, tasty-quickcheck, tardis, unification-fd, vector }:
mkDerivation (rec {
  pname = "Simplicity";
  version = "0.0.0";
  src = lib.sourceFilesBySuffices
      (lib.sourceByRegex ./. ["^LICENSE$" "^Simplicity\.cabal$" "^Setup.hs$" "^Tests.hs$" "^Haskell$" "^Haskell/.*"
                              "^C$" "^C/uword.h" "^C/bitstring.h" "^C/frame.*" "^C/jets.*" "^C/sha256.*" "^C/unreachable.h"
                              "^C/jets-secp256k1.c$" "^C/secp256k1$" "^C/secp256k1/.*"
                              "^C/include$" "^C/include/simplicity$" "^C/include/simplicity/elements$" "^C/include/simplicity/elements/env.h"
                              "^C/primitive$" "^C/primitive/elements$" "^C/primitive/elements/jets.*" "^C/primitive/elements/ops.*" "^C/primitive/elements/primitive.*" "^C/primitive/elements/env.c"])
    ["LICENSE" ".cabal" ".hs" ".hsig" ".h" ".c"];
  libraryHaskellDepends = [ base binary cereal lens-family MemoTrie mtl split tardis unification-fd vector ];
  testHaskellDepends = libraryHaskellDepends ++ [ QuickCheck tasty tasty-hunit tasty-quickcheck ];
  preCheck = ''
    export GHCRTS=-N$NIX_BUILD_CORES
  '';
  postCheck = ''
    unset GHCRTS
  '';
  # Uncomment to make testing deterministic.
  # testFlags = ["--quickcheck-replay=582534"];

  # Cabal's haddock doesn't work for Backpack / internal libraries / modules reexports.
  # Until that is fix we manually generate some documentation pages
  haddockFlags = ["--haddock-option='--use-contents=index.html'"];
  postInstall = ''
    cp ${./manual-index.html} $doc/share/doc/${pname}-${version}/html/index.html
    cp ${./Simplicity-Primitive.html} $doc/share/doc/${pname}-${version}/html/Simplicity-Primitive.html
  '';

  license = lib.licenses.mit;
})
