{
  buildGoModule,
  buildNpmPackage,
  fetchFromGitHub,
  go,
  installShellFiles,
  lib,
  stdenv,
  # Zot build is modular
  enableDebug ? false,
  enableImagetrust ? true,
  enableLint ? true,
  enableMetrics ? true,
  enableMgmt ? true,
  enableProfile ? true,
  enableScrub ? true,
  enableSearch ? true,
  enableSync ? true,
  enableUi ? true,
  enableUserprefs ? true,
}: let
  buildLabels =
    []
    ++ lib.optional enableDebug "debug"
    ++ lib.optional enableImagetrust "imagetrust"
    ++ lib.optional enableLint "lint"
    ++ lib.optional enableMetrics "metrics"
    ++ lib.optional enableMgmt "mgmt"
    ++ lib.optional enableProfile "profile"
    ++ lib.optional enableScrub "scrub"
    ++ lib.optional enableSearch "search"
    ++ lib.optional enableSync "sync"
    ++ lib.optional enableUi "ui"
    ++ lib.optional enableUserprefs "userprefs";

  binaryType =
    if (builtins.length buildLabels) > 0
    then (builtins.concatStringsSep "-" buildLabels)
    else "minimal";

  ui = buildNpmPackage rec {
    pname = "zui";
    version = "commit-c78b303";

    src = fetchFromGitHub {
      owner = "project-zot";
      repo = "zui";
      rev = "refs/tags/${version}";
      hash = "sha256-NWa3WgG46bdSvHpJJasb4VlwuY7g3JQaG6fgJRRIsmQ=";
    };

    npmDepsHash = "sha256-bSWe2CfLD+bUCB/7HaPEOwX6tDk4POteKpQprolTeIE=";

    installPhase = ''
      mkdir -p $out
      cp -R build $out/
    '';
  };
in
  buildGoModule rec {
    pname = "zot";
    version = "2.1.1";

    src = fetchFromGitHub {
      owner = "project-zot";
      repo = "zot";
      rev = "refs/tags/v${version}";
      hash = "sha256-h7c+MJHy6+/WIlpnaLhnXzeA0due6n4V/uLCoiXhijU=";
      leaveDotGit = true;
      postFetch = ''
        cd "$out"
        git rev-parse HEAD > $out/COMMIT
        find "$out" -name .git -print0 | xargs -0 rm -rf
      '';
    };

    vendorHash = "sha256-cHJkBbOTJhP/gOewGFjAXX/AVNEZ5IXcBJ/bj9vR9KY=";

    proxyVendor = true;

    subPackages = ["cmd/zot"];

    tags =
      ["containers_image_openpgp"] ++ buildLabels;

    CGO_ENABLED = "0";

    ldflags = [
      "-s"
      "-w"
      "-X zotregistry.dev/zot/pkg/api/config.ReleaseTag=${version}"
      "-X zotregistry.dev/zot/pkg/api/config.BinaryType=${binaryType}"
      "-X zotregistry.dev/zot/pkg/api/config.GoVersion=${go.version}"
    ];

    preBuild =
      ''
        ldflags+=" -X zotregistry.dev/zot/pkg/api/config.Commit=$(cat COMMIT)"
      ''
      + lib.optionalString enableUi ''
        cp -R ${ui}/* pkg/extensions/
      '';

    nativeBuildInputs = [installShellFiles];

    postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
      installShellCompletion --cmd $pname \
        --bash <($out/bin/$pname completion bash) \
        --fish <($out/bin/$pname completion fish) \
        --zsh <($out/bin/$pname completion zsh)
    '';

    meta = {
      description = "A scale-out production-ready vendor-neutral OCI-native container image/artifact registry";
      homepage = "https://zotregistry.dev";
      changelog = "https://github.com/project-zot/zot/releases/tag/v${version}";
      license = lib.licenses.asl20;
      maintainers = [lib.maintainers.nicolasbernard];
      mainProgram = "zot";
    };
  }
