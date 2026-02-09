# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────── d-separation ─────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Are X and Y d-separated given Z?
#'
#' @description Checks whether every node in `X` is d-separated from every node
#' in `Y` given `Z` in a DAG.
#'
#' @param cg A `caugi` object.
#' @param X,Y,Z Node selectors: character vector of names, unquoted expression
#'   (supports `+` and `c()`), or `NULL`. Use `*_index` to pass 1-based indices.
#'   If `Z` is `NULL` or missing, no nodes are conditioned on.
#' @param X_index,Y_index,Z_index Optional numeric 1-based indices (exclusive
#'   with `X`,`Y`,`Z` respectively).
#'
#' @returns `TRUE` if d-separated, `FALSE` otherwise.
#'
#' @examples
#' cg <- caugi(
#'   C %-->% X,
#'   X %-->% F,
#'   X %-->% D,
#'   A %-->% X,
#'   A %-->% K,
#'   K %-->% Y,
#'   D %-->% Y,
#'   D %-->% G,
#'   Y %-->% H,
#'   class = "DAG"
#' )
#'
#' d_separated(cg, "X", "Y", Z = c("A", "D")) # TRUE
#' d_separated(cg, "X", "Y", Z = NULL) # FALSE
#'
#' @family adjustment
#' @concept adjustment
#'
#' @export
d_separated <- function(
  cg,
  X = NULL,
  Y = NULL,
  Z = NULL,
  X_index = NULL,
  Y_index = NULL,
  Z_index = NULL
) {
  is_caugi(cg, throw_error = TRUE)
  if (
    length(X) > 1 || length(Y) > 1 || length(X_index) > 1 || length(Y_index) > 1
  ) {
    stop("Provide exactly one X and one Y.", call. = FALSE)
  }

  X_idx0 <- .resolve_idx0_get(cg@session, X, X_index)
  Y_idx0 <- .resolve_idx0_get(cg@session, Y, Y_index)
  Z_idx0 <- .resolve_idx0_mget(cg@session, Z, Z_index)

  rs_d_separated(cg@session, X_idx0, Y_idx0, Z_idx0)
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Adjustment sets ────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Compute an adjustment set
#'
#' @description Computes an adjustment set for `X -> Y` in a DAG.
#' @details
#' Types supported:
#' - `"parents"`: \eqn{\bigcup \mathrm{Pa}(X)} minus \eqn{X \cup Y}
#' - `"backdoor"`: Pearl backdoor formula
#' - `"optimal"`: O-set (only for single `x` and single `y`)
#'
#' @param cg A `caugi` object.
#' @param X,Y Node names.
#' @param X_index,Y_index Optional numeric 1-based indices.
#' @param type One of `"parents"`, `"backdoor"`, `"optimal"`.
#' The `optimal` option computes the O-set.
#'
#' @returns A character vector of node names representing the adjustment set.
#'
#' @examples
#' cg <- caugi(
#'   C %-->% X,
#'   X %-->% F,
#'   X %-->% D,
#'   A %-->% X,
#'   A %-->% K,
#'   K %-->% Y,
#'   D %-->% Y,
#'   D %-->% G,
#'   Y %-->% H,
#'   class = "DAG"
#' )
#'
#' adjustment_set(cg, "X", "Y", type = "parents") # C, A
#' adjustment_set(cg, "X", "Y", type = "backdoor") # C, A
#' adjustment_set(cg, "X", "Y", type = "optimal") # K
#'
#' @family adjustment
#' @concept adjustment
#'
#' @export
adjustment_set <- function(
  cg,
  X = NULL,
  Y = NULL,
  X_index = NULL,
  Y_index = NULL,
  type = c("optimal", "parents", "backdoor")
) {
  is_caugi(cg, throw_error = TRUE)
  if (
    length(X) > 1 || length(Y) > 1 || length(X_index) > 1 || length(Y_index) > 1
  ) {
    stop("Provide exactly one X and one Y.", call. = FALSE)
  }

  type <- match.arg(type)

  X_idx0 <- .resolve_idx0_get(cg@session, X, X_index)
  Y_idx0 <- .resolve_idx0_get(cg@session, Y, Y_index)

  idx0 <- switch(
    type,
    parents = rs_adjustment_set_parents(cg@session, X_idx0, Y_idx0),
    backdoor = rs_adjustment_set_backdoor(
      cg@session,
      X_idx0,
      Y_idx0
    ),
    optimal = rs_adjustment_set_optimal(cg@session, X_idx0, Y_idx0)
  )
  cg@nodes$name[idx0 + 1L]
}

#' @title Is a backdoor set valid?
#'
#' @description Checks whether `Z` is a valid backdoor adjustment set for
#' `X --> Y`.
#' @param cg A `caugi` object.
#'
#' @param X,Y Single node names.
#' @param Z Optional node set for conditioning
#' @param X_index,Y_index,Z_index Optional 1-based indices.
#'
#' @returns Logical value indicating if backdoor is valid or not.
#'
#' @examples
#' cg <- caugi(
#'   C %-->% X,
#'   X %-->% F,
#'   X %-->% D,
#'   A %-->% X,
#'   A %-->% K,
#'   K %-->% Y,
#'   D %-->% Y,
#'   D %-->% G,
#'   Y %-->% H,
#'   class = "DAG"
#' )
#'
#' is_valid_backdoor(cg, X = "X", Y = "Y", Z = NULL) # FALSE
#' is_valid_backdoor(cg, X = "X", Y = "Y", Z = "K") # TRUE
#' is_valid_backdoor(cg, X = "X", Y = "Y", Z = c("A", "C")) # TRUE
#'
#' @family adjustment
#' @concept adjustment
#'
#' @export
is_valid_backdoor <- function(
  cg,
  X = NULL,
  Y = NULL,
  Z = NULL,
  X_index = NULL,
  Y_index = NULL,
  Z_index = NULL
) {
  is_caugi(cg, throw_error = TRUE)
  if (
    length(X) > 1 || length(Y) > 1 || length(X_index) > 1 || length(Y_index) > 1
  ) {
    stop("Provide exactly one X and one Y.", call. = FALSE)
  }

  X_idx0 <- .resolve_idx0_get(cg@session, X, X_index)
  Y_idx0 <- .resolve_idx0_get(cg@session, Y, Y_index)
  Z_idx0 <- .resolve_idx0_mget(cg@session, Z, Z_index)

  rs_is_valid_backdoor_set(cg@session, X_idx0, Y_idx0, Z_idx0)
}

#' @title Get all backdoor sets up to a certain size.
#'
#' @description This function returns the backdoor sets up to size `max_size`,
#' which per default is set to 10.
#'
#' @param cg A `caugi`.
#' @param X,Y Single node name.
#' @param X_index,Y_index Optional 1-based indices (exclusive with name args).
#' @param minimal Logical; if `TRUE` (default), only minimal sets are returned.
#' @param max_size Integer; maximum size of sets to consider (default 3).
#'
#' @returns A list of character vectors, each an adjustment set
#' (possibly empty).
#'
#' @examples
#' cg <- caugi(
#'   C %-->% X,
#'   X %-->% F,
#'   X %-->% D,
#'   A %-->% X,
#'   A %-->% K,
#'   K %-->% Y,
#'   D %-->% Y,
#'   D %-->% G,
#'   Y %-->% H,
#'   class = "DAG"
#' )
#'
#' all_backdoor_sets(cg, X = "X", Y = "Y", max_size = 3L, minimal = FALSE)
#' #> [[1]]
#' #> [1] "A"
#' #>
#' #> [[2]]
#' #> [1] "K"
#' #>
#' #> [[3]]
#' #> [1] "C" "A"
#' #>
#' #> [[4]]
#' #> [1] "C" "K"
#' #>
#' #> [[5]]
#' #> [1] "A" "K"
#' #>
#' #> [[6]]
#' #> [1] "C" "A" "K"
#'
#' all_backdoor_sets(cg, X = "X", Y = "Y", max_size = 3L, minimal = TRUE)
#' #> [[1]]
#' #> [1] "A"
#' #>
#' #> [[2]]
#' #> [1] "K"
#'
#' @family adjustment
#' @concept adjustment
#'
#' @export
all_backdoor_sets <- function(
  cg,
  X = NULL,
  Y = NULL,
  X_index = NULL,
  Y_index = NULL,
  minimal = TRUE,
  max_size = 3L
) {
  is_caugi(cg, throw_error = TRUE)
  if (
    length(X) > 1 || length(Y) > 1 || length(X_index) > 1 || length(Y_index) > 1
  ) {
    stop("Provide exactly one X and one Y.", call. = FALSE)
  }

  X_idx0 <- .resolve_idx0_get(cg@session, X, X_index)
  Y_idx0 <- .resolve_idx0_get(cg@session, Y, Y_index)

  sets_idx0 <- rs_all_backdoor_sets(
    cg@session,
    X_idx0,
    Y_idx0,
    minimal,
    as.integer(max_size)
  )
  nm <- cg@nodes$name
  lapply(sets_idx0, \(idx0) nm[idx0 + 1L])
}

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────── ADMG Adjustment Functions ───────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Is a set a valid adjustment set in an ADMG?
#'
#' @description Checks whether `Z` is a valid adjustment set for estimating
#' the causal effect of `X` on `Y` in an ADMG using the generalized adjustment
#' criterion.
#'
#' @param cg A `caugi` object of class ADMG.
#' @param X,Y Node names (can be vectors for multiple treatments/outcomes).
#' @param Z Conditioning set (character vector of node names).
#' @param X_index,Y_index,Z_index Optional 1-based indices.
#'
#' @returns Logical value indicating if the adjustment set is valid.
#'
#' @examples
#' # Classic confounding
#' cg <- caugi(
#'   L %-->% X,
#'   X %-->% Y,
#'   L %-->% Y,
#'   class = "ADMG"
#' )
#'
#' is_valid_adjustment_admg(cg, X = "X", Y = "Y", Z = NULL) # FALSE
#' is_valid_adjustment_admg(cg, X = "X", Y = "Y", Z = "L") # TRUE
#'
#' @family adjustment
#' @concept adjustment
#'
#' @export
is_valid_adjustment_admg <- function(
  cg,
  X = NULL,
  Y = NULL,
  Z = NULL,
  X_index = NULL,
  Y_index = NULL,
  Z_index = NULL
) {
  is_caugi(cg, throw_error = TRUE)
  # Validate that X and Y are provided

  if (is.null(X) && is.null(X_index)) {
    stop("X (or X_index) must be provided.", call. = FALSE)
  }
  if (is.null(Y) && is.null(Y_index)) {
    stop("Y (or Y_index) must be provided.", call. = FALSE)
  }

  X_idx0 <- .resolve_idx0_mget(cg@session, X, X_index)
  Y_idx0 <- .resolve_idx0_mget(cg@session, Y, Y_index)
  Z_idx0 <- .resolve_idx0_mget(cg@session, Z, Z_index)

  rs_is_valid_adjustment_set_admg(cg@session, X_idx0, Y_idx0, Z_idx0)
}

#' @title Get all valid adjustment sets in an ADMG
#'
#' @description Enumerates all valid adjustment sets for estimating the causal
#' effect of `X` on `Y` in an ADMG, up to a specified maximum size.
#'
#' @param cg A `caugi` object of class ADMG.
#' @param X,Y Node names (can be vectors for multiple treatments/outcomes).
#' @param X_index,Y_index Optional 1-based indices.
#' @param minimal Logical; if `TRUE` (default), only minimal sets are returned.
#' @param max_size Integer; maximum size of sets to consider (default 3).
#'
#' @returns A list of character vectors, each a valid adjustment set
#' (possibly empty list if none exist).
#'
#' @examples
#' cg <- caugi(
#'   L %-->% X,
#'   X %-->% Y,
#'   L %-->% Y,
#'   M %-->% Y,
#'   class = "ADMG"
#' )
#'
#' all_adjustment_sets_admg(cg, X = "X", Y = "Y", minimal = TRUE)
#' # Returns {L} as minimal adjustment set
#'
#' @family adjustment
#' @concept adjustment
#'
#' @export
all_adjustment_sets_admg <- function(
  cg,
  X = NULL,
  Y = NULL,
  X_index = NULL,
  Y_index = NULL,
  minimal = TRUE,
  max_size = 3L
) {
  is_caugi(cg, throw_error = TRUE)
  # Validate that X and Y are provided
  if (is.null(X) && is.null(X_index)) {
    stop("X (or X_index) must be provided.", call. = FALSE)
  }
  if (is.null(Y) && is.null(Y_index)) {
    stop("Y (or Y_index) must be provided.", call. = FALSE)
  }

  X_idx0 <- .resolve_idx0_mget(cg@session, X, X_index)
  Y_idx0 <- .resolve_idx0_mget(cg@session, Y, Y_index)

  sets_idx0 <- rs_all_adjustment_sets_admg(
    cg@session,
    X_idx0,
    Y_idx0,
    minimal,
    as.integer(max_size)
  )
  nm <- cg@nodes$name
  lapply(sets_idx0, \(idx0) nm[idx0 + 1L])
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Helpers ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Resolve node name or index to 0-based index.
#'
#' @description Internal helper function to resolve either a node name or a
#' node index to a 0-based index using the Rust session.
#' `.resolve_idx0_get` expects a single value,
#' while `.resolve_idx0_mget` can return multiple values.
#'
#' @param session A GraphSession pointer.
#' @param node_name Optional character vector of node names.
#' @param node_index Optional numeric vector of 1-based node indices.
#'
#' @name .resolve_idx0_get
#'
#' @keywords internal
.resolve_idx0_get <- function(session, node_name = NULL, node_index = NULL) {
  if (!is.null(node_index)) {
    if (!is.null(node_name)) {
      stop("Provide either a node name or node index.", call. = FALSE)
    }
    as.integer(node_index - 1L)
  } else if (!is.null(node_name)) {
    rs_index_of(session, node_name)
  } else {
    stop(
      "Either the node name or the node index must be provided.",
      call. = FALSE
    )
  }
}

#' @name .resolve_idx0_get
#' @keywords internal
.resolve_idx0_mget <- function(session, node_name = NULL, node_index = NULL) {
  if (is.null(node_name) && is.null(node_index)) {
    integer(0)
  } else if (!is.null(node_index)) {
    if (!is.null(node_name)) {
      stop("Provide either a node name or node index.", call. = FALSE)
    }
    as.integer(node_index - 1L)
  } else if (!is.null(node_name)) {
    rs_indices_of(session, node_name)
  }
}
