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
}

# nocov end
