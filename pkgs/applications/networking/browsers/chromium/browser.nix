{
  lib,
  mkChromiumDerivation,
  chromiumVersionAtLeast,
  enableWideVine,
  variant,
}:

let
  # https://chromium-review.googlesource.com/c/chromium/src/+/7253206
  ifElseM145 = new: old: if chromiumVersionAtLeast "145" then new else old;

  browserName = if variant == "helium" then "helium" else "chromium";
  binaryName = if variant == "helium" then "helium" else "chrome";
  crashpadName = if variant == "helium" then "helium_crashpad_handler" else "chrome_crashpad_handler";
  desktopFileName = if variant == "helium" then "helium.desktop" else "${browserName}-browser.desktop";
  uriScheme = if variant == "helium" then "x-scheme-handler/helium;" else "x-scheme-handler/chromium;";
  menuName = if variant == "helium" then "Helium" else "${lib.toSentenceCase browserName}";
  wmClass = if variant == "helium" then "helium-browser" else "${browserName}-browser";
in

mkChromiumDerivation (base: rec {
  name = "${browserName}-browser";
  packageName = browserName;
  buildTargets = [
    "chrome_sandbox"
    "chrome"
  ];

  outputs = [
    "out"
    "sandbox"
  ];

  sandboxExecutableName = "__chromium-suid-sandbox";

  installPhase = ''
    mkdir -p "$libExecPath"
    cp -v "$buildPath/"*.so "$buildPath/"*.pak "$buildPath/"*.bin "$libExecPath/"
    cp -v "$buildPath/libvulkan.so.1" "$libExecPath/"
    cp -v "$buildPath/vk_swiftshader_icd.json" "$libExecPath/"
    cp -v "$buildPath/icudtl.dat" "$libExecPath/"
    cp -vLR "$buildPath/locales" "$buildPath/resources" "$libExecPath/"
    cp -v "$buildPath/${crashpadName}" "$libExecPath/"
    cp -v "$buildPath/${binaryName}" "$libExecPath/$packageName"

    # Swiftshader
    # See https://stackoverflow.com/a/4264351/263061 for the find invocation.
    if [ -n "$(find "$buildPath/swiftshader/" -maxdepth 1 -name '*.so' -print -quit)" ]; then
      echo "Swiftshader files found; installing"
      mkdir -p "$libExecPath/swiftshader"
      cp -v "$buildPath/swiftshader/"*.so "$libExecPath/swiftshader/"
    else
      echo "Swiftshader files not found"
    fi

    mkdir -p "$sandbox/bin"
    cp -v "$buildPath/chrome_sandbox" "$sandbox/bin/${sandboxExecutableName}"

    mkdir -vp "$out/share/man/man1"
    cp -v "$buildPath/chrome.1" "$out/share/man/man1/$packageName.1"

    for icon_file in chrome/app/theme/chromium/product_logo_*[0-9].png; do
      num_and_suffix="''${icon_file##*logo_}"
      icon_size="''${num_and_suffix%.*}"
      expr "$icon_size" : "^[0-9][0-9]*$" || continue
      logo_output_prefix="$out/share/icons/hicolor"
      logo_output_path="$logo_output_prefix/''${icon_size}x''${icon_size}/apps"
      mkdir -vp "$logo_output_path"
      cp -v "$icon_file" "$logo_output_path/$packageName.png"
    done

    install -D chrome/installer/linux/common/desktop.template \
      $out/share/applications/${desktopFileName}

    substituteInPlace $out/share/applications/${desktopFileName} \
      --replace-fail "${ifElseM145 "@@MENUNAME" "@@MENUNAME@@"}" "${menuName}" \
      --replace-fail "${ifElseM145 "@@PACKAGE" "@@PACKAGE@@"}" "${browserName}" \
      --replace-fail "${ifElseM145 "/usr/bin/@@usr_bin_symlink_name" "/usr/bin/@@USR_BIN_SYMLINK_NAME@@"}" "${browserName}" \
      --replace-fail "${ifElseM145 "@@uri_scheme" "@@URI_SCHEME@@"}" "${uriScheme}" \
      --replace-fail "${ifElseM145 "@@extra_desktop_entries" "@@EXTRA_DESKTOP_ENTRIES@@"}" ""

    substituteInPlace $out/share/applications/${desktopFileName} \
      --replace-fail "[Desktop Entry]" "[Desktop Entry]''\nStartupWMClass=${wmClass}"

    if grep -F '@@' $out/share/applications/${desktopFileName} ; then
      echo "error: ${desktopFileName} contains unsubstituted placeholders" >&2
      exit 1
    fi
  '';

  passthru = { inherit sandboxExecutableName; };

  requiredSystemFeatures = [ "big-parallel" ];

  meta =
    let
      upstreamMeta = (import ./variants/meta.nix lib).${variant}.meta;
    in
    upstreamMeta
    // {
      license = if enableWideVine then lib.licenses.unfree else lib.licenses.bsd3;
      platforms = lib.platforms.linux;
      hydraPlatforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      timeout = 172800; # 48 hours (increased from the Hydra default of 10h)
    };
})
