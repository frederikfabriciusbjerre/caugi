{
  pkgs,
  ...
}:

{
  packages = [
    pkgs.air-formatter
    pkgs.bashInteractive
    pkgs.cargo-audit
    pkgs.cargo-deny
    pkgs.html-tidy
    pkgs.cargo-flamegraph
    pkgs.cargo-llvm-cov
    pkgs.poppler
    pkgs.go-task
    pkgs.jarl
    pkgs.llvmPackages.bintools
  ];

  languages = {
    rust = {
      enable = true;
    };

    python = {
      enable = true;

      package = (
        pkgs.python3.withPackages (
          ps: with ps; [
            pymupdf4llm
            pypdf
            pypdf2
          ]
        )
      );
    };

    r = {
      enable = true;

      package = (
        pkgs.rWrapper.override {
          packages = with pkgs.rPackages; [
            bench
            bnlearn
            dagitty
            data_table
            devtools
            dplyr
            fastmap
            ggbeeswarm
            ggm
            graph
            gRbase
            gridExtra
            igraph
            jsonlite
            knitr
            MASS
            Matrix
            pcalg
            processx
            rextendr
            rhub
            rlang
            rmarkdown
            S7
            spelling
            testthat
            tidyverse
            urlchecker
            usethis
            waldo
            withr
          ];
        }
      );

      lsp.enable = true;
    };
  };
}
