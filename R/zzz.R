#' @useDynLib caugi, .registration = TRUE
#' @importFrom cpp11 cpp_register
.onLoad <- function(libname, pkgname) {
  invisible(NULL)
}
