{
  pkgs,
  kutils,
  params,
  buildEnv,
  ...
}: let
  kallPackage = kutils.buildCallPackage params;

  custom_fonts = kutils.genPkgAttrset [
    (kallPackage ./kfonts.nix {})
    (kallPackage ./firacode.nix {})
  ];

  allFonts = buildEnv {
    name = "kuriko-all-fonts";
    version = "1.0.0";
    paths = with pkgs;
      [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif

        sarasa-gothic

        wqy_zenhei
        wqy_microhei

        # Coding
        inconsolata
        maple-mono.CN
        _0xproto
        jetbrains-mono
      ]
      ++ (builtins.attrValues custom_fonts);
  };
in
  {
    recurseForDerivations = true;
    inherit allFonts;
  }
  // custom_fonts
