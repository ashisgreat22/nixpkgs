{
  stdenv,
  lib,
  fetchFromGitHub,
  fetchurl,
  python3,
  makeWrapper,
  patch,
}:

{
  rev,
  hash,
  ...
}@args:

let
  helium-linux =
    if args ? helium-linux
    then fetchFromGitHub ({
      owner = "imputnet";
      repo = "helium-linux";
    } // args.helium-linux)
    else null;

  helium-onboarding =
    if args ? helium-onboarding
    then fetchurl args.helium-onboarding
    else null;

  helium-ublock =
    if args ? helium-ublock
    then fetchurl args.helium-ublock
    else null;

  helium-search-engines-data =
    if args ? helium-search-engines-data
    then fetchurl args.helium-search-engines-data
    else null;
in

stdenv.mkDerivation {
  pname = "helium";

  version = rev;

  src = fetchFromGitHub {
    owner = "imputnet";
    repo = "helium";
    inherit rev hash;
  };

  buildInputs = [
    (python3.withPackages (ps: with ps; [ pillow ]))
    patch
  ];

  nativeBuildInputs = [
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild
    python3 ./utils/generate_resources.py ./resources/generate_resources.txt ./resources
    sed -i '/chromium-widevine/d' patches/series
    runHook postBuild
  '';

  installPhase = ''
    mkdir $out
    cp -R * $out/
    wrapProgram $out/utils/patches.py --add-args "apply" --prefix PATH : "${patch}/bin"
  ''
  + lib.optionalString (helium-linux != null) ''
    ln -s ${helium-linux} $out/helium-linux
    ln -s ${helium-onboarding} $out/helium-onboarding
    ln -s ${helium-ublock} $out/helium-ublock
    ln -s ${helium-search-engines-data} $out/helium-search-engines-data
  '';
}
