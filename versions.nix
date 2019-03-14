let
  # https://vaibhavsagar.com/blog/2018/05/27/quick-easy-nixpkgs-pinning/
  fetcher = { owner?null, repo?null, rev, sha256, branch
    , url ? "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz"
  }: if owner == null then
    builtins.fetchGit {
      inherit url rev;
    }
  else
    builtins.fetchTarball {
      inherit url sha256;
    };
  versions = builtins.mapAttrs
     (_: fetchOrPath) sources;

  sources = (builtins.fromJSON (builtins.readFile ./versions.json));

  NIX_PATH = builtins.concatStringsSep ":" (builtins.map (x: "${x}=${versions."${x}"}") (builtins.attrNames versions));

  fetchOrPath = value:
    if builtins.typeOf value == "set" then
      fetcher value
    else
      toString value;

  inherit (import versions.nixpkgs {}) writeScript;
  updater = writeScript "updater.sh" ''
    #!/usr/bin/env bash
    ${./version-updater.sh} versions.json nixpkgs_pu
  '';
in versions // { inherit updater NIX_PATH sources; }
