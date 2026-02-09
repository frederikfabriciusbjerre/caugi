# nocov start

#' @useDynLib caugi, .registration = TRUE
.onLoad <- function(libname, pkgname) {
  if (isNamespaceLoaded("graph")) {
    register_graphnel_s4_class()
  }

  setHook(
    packageEvent("graph", "onLoad"),
    function(...) {
      register_graphnel_s4_class()
    }
  )

  if (isNamespaceLoaded("Matrix")) {
    register_matrix_s4_class()
  }

  setHook(
    packageEvent("Matrix", "onLoad"),
    function(...) {
      register_matrix_s4_class()
    }
  )

  caugi_options(caugi_default_options())
  S7::methods_register()

  # Register waldo compare_proxy for caugi (for testthat edition 3)
  register_waldo_method <- function() {
    if (requireNamespace("waldo", quietly = TRUE)) {
      registerS3method(
        "compare_proxy",
        "caugi::caugi",
        `compare_proxy.caugi::caugi`,
        envir = asNamespace("waldo")
      )
    }
  }

  if (isNamespaceLoaded("waldo")) {
    register_waldo_method()
  }

  setHook(
    packageEvent("waldo", "onLoad"),
    function(...) {
      register_waldo_method()
    }
  )

  # Register all.equal method for caugi (for testthat edition 2)
  registerS3method(
    "all.equal",
    "caugi::caugi",
    `all.equal.caugi::caugi`,
    envir = asNamespace("base")
  )
}

# nocov end
