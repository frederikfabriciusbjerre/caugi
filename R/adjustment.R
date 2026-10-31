# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────── d-separation ─────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Are X and Y d-separated given Z?
#'
#' @description Checks whether every node in `X` is d-separated from every node
#' in `Y` given `Z` in a DAG.
#'
#' @param cg A `caugi` object.
#' @param X,Y,Z Character vectors of node names, or `NULL`. If `Z` is `NULL`
#'   or missing, no nodes are conditioned on.
#' @param X_index,Y_index,Z_index Deprecated; pass node names instead.
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
#' d_separated(cg, c("C", "X"), c("K", "Y"), Z = c("A", "D")) # TRUE
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
  .warn_index_deprecated()
  X_idx0 <- .resolve_idx0_xy(cg@session, X, X_index, "X")
  Y_idx0 <- .resolve_idx0_xy(cg@session, Y, Y_index, "Y")
  Z_idx0 <- .resolve_idx0_mget(cg@session, Z, Z_index)

  rs_d_separated(cg@session, X_idx0, Y_idx0, Z_idx0)
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Adjustment sets ────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Compute an adjustment set
#'
#' @description Computes an adjustment set for the effect of `X` on `Y` in a
#' DAG. `X` and `Y` can each hold one or more nodes.
#' @details
#' Types supported:
#' - `"parents"`: \eqn{\bigcup \mathrm{Pa}(X)} minus \eqn{X \cup Y}. With a
#'   single treatment this is valid whenever any valid set exists. With several
#'   treatments it can fail while other sets work, because a parent of one
#'   treatment can lie on a causal path from another.
#' - `"backdoor"`: an inclusion-minimal valid adjustment set, found in
#'   linear time as a minimal d-separator of `X` and `Y` in the proper backdoor
#'   graph (van der Zander, Liśkiewicz & Textor, 2019). It finds a valid set
#'   whenever one exists. Unlike `"parents"` (which always conditions on every
#'   parent of `X`), this drops nodes that are not needed to block a backdoor
#'   path. Note that minimal is not the same as statistically optimal; use
#'   `"optimal"` for the efficient O-set.
#' - `"optimal"`: the O-set \eqn{\mathrm{Pa}(\mathrm{cn}(X, Y)) \setminus
#'   \mathrm{forb}(X, Y)} (Henckel, Perković & Maathuis, 2022). Following
#'   their Remark 3.14, nodes of `Y` that are not descendants of `X` are
#'   dropped with a warning, since the total effect on them is zero, and the
#'   O-set is computed for the rest of `Y`. It is then valid whenever any valid
#'   set exists. If no node of `Y` is a descendant of `X`, an error is raised.
#'   A dropped node can itself be in the O-set: for `X --> Y1 <-- Y2` with
#'   `Y = c("Y1", "Y2")`, `Y2` is dropped from `Y` and returned as the O-set,
#'   since it is a parent of `Y1`.
#'
#' Every result is checked against the generalized adjustment criterion
#' (Perković et al., 2018). An error is raised when the requested set is not
#' valid. In particular, a valid set need not exist with several treatments:
#' in `X1 --> L --> X2`, `L --> Y`, only `L` blocks `X2 <-- L --> Y`, but it
#' lies on the causal path `X1 --> L --> Y`. With a single treatment, no valid
#' set exists only when a node of `Y` is a parent of `X`.
#'
#' @param cg A `caugi` object.
#' @param X,Y Node names; one or more each, and disjoint.
#' @param X_index,Y_index Deprecated; pass node names instead.
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
#' adjustment_set(cg, "X", "Y", type = "backdoor") # A
#' adjustment_set(cg, "X", "Y", type = "optimal") # K
#'
#' # Several treatments
#' cg2 <- caugi(X1 %-->% W, W %-->% X2, X2 %-->% Y, U %-->% W + Y, class = "DAG")
#' adjustment_set(cg2, c("X1", "X2"), "Y", type = "optimal") # U
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
  .warn_index_deprecated()
  type <- match.arg(type)

  if (is.null(X) && is.null(X_index)) {
    stop("X must be provided.", call. = FALSE)
  }
  if (is.null(Y) && is.null(Y_index)) {
    stop("Y must be provided.", call. = FALSE)
  }
  X_idx0 <- unique(.resolve_idx0_mget(cg@session, X, X_index))
  Y_idx0 <- unique(.resolve_idx0_mget(cg@session, Y, Y_index))
  if (length(X_idx0) == 0L) {
    stop("`X` must name at least one node.", call. = FALSE)
  }
  if (length(Y_idx0) == 0L) {
    stop("`Y` must name at least one node.", call. = FALSE)
  }
  if (any(X_idx0 %in% Y_idx0)) {
    stop("X and Y must be disjoint.", call. = FALSE)
  }

  idx0 <- switch(
    type,
    parents = rs_adjustment_set_parents(cg@session, X_idx0, Y_idx0),
    backdoor = rs_adjustment_set_backdoor(
      cg@session,
      X_idx0,
      Y_idx0
    ),
    optimal = {
      # Rust drops the nodes of Y that are not descendants of X (Henckel et
      # al., 2022, Remark 3.14) and reports them.
      res <- rs_adjustment_set_optimal(cg@session, X_idx0, Y_idx0, TRUE)
      if (length(res$dropped) > 0) {
        warning(
          "Not a descendant of X, so dropped from Y (the effect on it is ",
          "zero): ",
          paste(cg@nodes$name[res$dropped + 1L], collapse = ", "),
          ". The O-set is for the rest of Y.",
          call. = FALSE
        )
      }
      res$set
    }
  )
  cg@nodes$name[idx0 + 1L]
}

#' @title Is a backdoor set valid?
#'
#' @description Checks whether `Z` satisfies the generalized back-door
#' criterion relative to `X` and `Y` in a DAG. `X` and `Y` can each hold one
#' or more nodes.
#'
#' @details
#' `Z` satisfies the generalized back-door criterion (Maathuis & Colombo,
#' 2015, Def. 3.7) when
#' 1. `Z` contains no descendant of `X`, and
#' 2. for every node \eqn{X_i} in `X`, \eqn{Z \cup X \setminus \{X_i\}} blocks
#'    every back-door path (a path starting with an edge into \eqn{X_i}) from
#'    \eqn{X_i} to `Y`.
#'
#' With one treatment and one outcome this is Pearl's back-door criterion.
#' With several treatments it can accept sets that Pearl's set version
#' rejects, since that version requires `Z` alone to block every back-door
#' path of each treatment. Every set accepted here is a valid adjustment set,
#' but a valid adjustment set may be rejected, for example one containing a
#' descendant of `X` off the causal paths. A `Z` that contains a node of `X`
#' or `Y` is never valid.
#'
#' @references
#' Maathuis, M. H. & Colombo, D. (2015). A generalized back-door criterion.
#' \emph{The Annals of Statistics}, 43(3), 1060--1088.
#' \doi{10.1214/14-AOS1295}.
#'
#' @param cg A `caugi` object.
#'
#' @param X,Y Node names; one or more each, and disjoint.
#' @param Z Optional node set for conditioning
#' @param X_index,Y_index,Z_index Deprecated; pass node names instead.
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
#' # Several treatments: X2 blocks X1 <-- X2 --> Y, so no adjustment is needed
#' cg2 <- caugi(X2 %-->% X1 + Y, X1 %-->% Y, class = "DAG")
#' is_valid_backdoor(cg2, X = c("X1", "X2"), Y = "Y", Z = NULL) # TRUE
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
  .warn_index_deprecated()
  X_idx0 <- .resolve_idx0_xy(cg@session, X, X_index, "X")
  Y_idx0 <- .resolve_idx0_xy(cg@session, Y, Y_index, "Y")
  if (any(X_idx0 %in% Y_idx0)) {
    stop("X and Y must be disjoint.", call. = FALSE)
  }
  Z_idx0 <- .resolve_idx0_mget(cg@session, Z, Z_index)

  rs_is_valid_backdoor_set(cg@session, X_idx0, Y_idx0, Z_idx0)
}

#' @title Get all backdoor sets up to a certain size.
#'
#' @description This function returns the backdoor sets up to size `max_size`,
#' which per default is set to 3. A set is a backdoor set when
#' [is_valid_backdoor()] accepts it, i.e. it satisfies the generalized
#' back-door criterion.
#'
#' @param cg A `caugi`.
#' @param X,Y Node names; one or more each, and disjoint.
#' @param X_index,Y_index Deprecated; pass node names instead.
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
  .warn_index_deprecated()
  X_idx0 <- .resolve_idx0_xy(cg@session, X, X_index, "X")
  Y_idx0 <- .resolve_idx0_xy(cg@session, Y, Y_index, "Y")
  if (any(X_idx0 %in% Y_idx0)) {
    stop("X and Y must be disjoint.", call. = FALSE)
  }

  sets_idx0 <- rs_all_backdoor_sets(
    cg@session,
    X_idx0,
    Y_idx0,
    minimal,
    .check_max_size(max_size)
  )
  nm <- cg@nodes$name
  lapply(sets_idx0, \(idx0) nm[idx0 + 1L])
}

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────── Minimal separator ─────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Compute a minimal separator
#'
#' @description Computes a minimal separator Z for sets X and Y, optionally with
#' mandatory inclusions and restrictions on the separator. Supports DAGs (where
#' the result is a d-separator), ADMGs, ancestral graphs and PAGs (where the
#' result is an m-separator).
#'
#' @details
#' A separator Z for X and Y is a set of nodes such that conditioning on Z
#' d- or m-separates X from Y in the graph. This function returns a minimal
#' separator: no proper subset of Z (excluding I) still separates X and Y.
#'
#' The algorithm runs in linear time O(n + m) and is unified across graph
#' classes via the Bayes-ball reachability of van der Zander & Liśkiewicz
#' (2020). For DAGs the algorithm specializes to FINDMINSEPINDAG; for ADMGs and
#' AGs (including MAGs) it uses the general FINDMINSEP over mixed graphs. For a
#' PAG it runs on a member MAG from [pag_to_mag()], which is exact since every
#' member encodes the same m-separations.
#'
#' @param cg A `caugi` object (DAG, ADMG, AG, or PAG).
#' @param X,Y Character vectors of node names.
#' @param I Nodes that must be included in the separator.
#' @param R Nodes allowed in the separator. If `NULL`, uses all nodes excluding
#'   X and Y.
#' @param X_index,Y_index,I_index,R_index Deprecated; pass node names instead.
#'
#' @returns A character vector of node names representing the minimal separator,
#' or `NULL` if no valid separator exists within the restriction R.
#'
#' @source van der Zander, B. & Liśkiewicz, M. (2020). Finding Minimal
#'   d-separators in Linear Time and Applications. Proceedings of The 35th
#'   Uncertainty in Artificial Intelligence Conference, in Proceedings of
#'   Machine Learning Research 115:637-647 Available from
#'   <https://proceedings.mlr.press/v115/van-der-zander20a.html>.
#'
#' @references
#' van der Zander, B. & Liśkiewicz, M. (2020). Finding Minimal d-separators in
#' Linear Time and Applications. In \emph{Proceedings of the 35th Conference on
#' Uncertainty in Artificial Intelligence (UAI 2020)}, PMLR 115:637--647.
#' \url{https://proceedings.mlr.press/v115/van-der-zander20a.html}.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% X,
#'   X %-->% M,
#'   M %-->% Y,
#'   A %-->% Y,
#'   class = "DAG"
#' )
#'
#' # Find any minimal separator between X and Y
#' minimal_separator(cg, "X", "Y")
#'
#' # Force M to be in the separator
#' minimal_separator(cg, "X", "Y", I = "M")
#'
#' # Restrict separator to only {A, M}
#' minimal_separator(cg, "X", "Y", R = c("A", "M"))
#'
#' # Works on ADMGs (returns a minimal m-separator)
#' admg <- caugi(
#'   L %-->% X,
#'   L %-->% Y,
#'   class = "ADMG"
#' )
#' minimal_separator(admg, "X", "Y") # "L"
#'
#' # Adjacent nodes cannot be separated
#' minimal_separator(add_edges(admg, X %-->% Y), "X", "Y") # NULL
#'
#' @family adjustment
#' @concept adjustment
#'
#' @export
minimal_separator <- function(
  cg,
  X = NULL,
  Y = NULL,
  I = character(0),
  R = NULL,
  X_index = NULL,
  Y_index = NULL,
  I_index = NULL,
  R_index = NULL
) {
  is_caugi(cg, throw_error = TRUE)
  .warn_index_deprecated()

  if (
    !is_dag(cg) &&
      !is_admg(cg) &&
      !is_ag(cg) &&
      !identical(cg@graph_class, "PAG")
  ) {
    stop(
      "`minimal_separator()` is only defined for DAGs, ADMGs, AGs, and PAGs. ",
      "The graph has class \"",
      cg@graph_class,
      "\".",
      call. = FALSE
    )
  }

  # Resolve X and Y indices
  X_idx0 <- .resolve_idx0_mget(cg@session, X, X_index)
  Y_idx0 <- .resolve_idx0_mget(cg@session, Y, Y_index)

  # Validate that X and Y resolve to non-empty node sets
  if (length(X_idx0) == 0L) {
    stop(
      "`X` did not match any nodes in the graph. Check that the node names exist.",
      call. = FALSE
    )
  }
  if (length(Y_idx0) == 0L) {
    stop(
      "`Y` did not match any nodes in the graph. Check that the node names exist.",
      call. = FALSE
    )
  }
  # Resolve I indices (default to empty)
  I_idx0 <- .resolve_idx0_mget(cg@session, I, I_index)

  # Resolve R indices (default to all nodes except X and Y)
  if (is.null(R) && is.null(R_index)) {
    # Default: all nodes except X and Y
    all_idx0 <- seq.int(0L, nrow(cg@nodes) - 1L)
    R_idx0 <- setdiff(setdiff(all_idx0, X_idx0), Y_idx0)
  } else {
    R_idx0 <- .resolve_idx0_mget(cg@session, R, R_index)
  }

  # Call Rust function
  result_idx0 <- rs_minimal_separator(
    cg@session,
    as.integer(X_idx0),
    as.integer(Y_idx0),
    as.integer(I_idx0),
    as.integer(R_idx0)
  )

  # Convert result
  if (is.null(result_idx0)) {
    return(NULL)
  }

  # Convert 0-based indices to node names
  nm <- cg@nodes$name
  nm[result_idx0 + 1L]
}

#' @rdname minimal_separator
#' @export
minimal_d_separator <- function(
  cg,
  X = NULL,
  Y = NULL,
  I = character(0),
  R = NULL,
  X_index = NULL,
  Y_index = NULL,
  I_index = NULL,
  R_index = NULL
) {
  .Deprecated("minimal_separator")
  minimal_separator(
    cg = cg,
    X = X,
    Y = Y,
    I = I,
    R = R,
    X_index = X_index,
    Y_index = Y_index,
    I_index = I_index,
    R_index = R_index
  )
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
#' @param X_index,Y_index,Z_index Deprecated; pass node names instead.
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
  .warn_index_deprecated()
  # Validate that X and Y are provided

  if (is.null(X) && is.null(X_index)) {
    stop("X must be provided.", call. = FALSE)
  }
  if (is.null(Y) && is.null(Y_index)) {
    stop("Y must be provided.", call. = FALSE)
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
#' @param X_index,Y_index Deprecated; pass node names instead.
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
  .warn_index_deprecated()
  # Validate that X and Y are provided
  if (is.null(X) && is.null(X_index)) {
    stop("X must be provided.", call. = FALSE)
  }
  if (is.null(Y) && is.null(Y_index)) {
    stop("Y must be provided.", call. = FALSE)
  }

  X_idx0 <- .resolve_idx0_mget(cg@session, X, X_index)
  Y_idx0 <- .resolve_idx0_mget(cg@session, Y, Y_index)

  sets_idx0 <- rs_all_adjustment_sets_admg(
    cg@session,
    X_idx0,
    Y_idx0,
    minimal,
    .check_max_size(max_size)
  )
  nm <- cg@nodes$name
  lapply(sets_idx0, \(idx0) nm[idx0 + 1L])
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Helpers ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Resolve node names or indices to 0-based indices.
#'
#' @description Internal helpers that resolve node names, or 1-based node
#' indices, to 0-based indices using the Rust session.
#' `.resolve_idx0_xy` also requires at least one node.
#'
#' @param session A GraphSession pointer.
#' @param node_name Optional character vector of node names.
#' @param node_index Optional numeric vector of 1-based node indices.
#'
#' @name .resolve_idx0_mget
#'
#' @keywords internal
.resolve_idx0_xy <- function(session, node_name, node_index, arg) {
  if (is.null(node_name) && is.null(node_index)) {
    stop(arg, " must be provided.", call. = FALSE)
  }
  idx0 <- .resolve_idx0_mget(session, node_name, node_index)
  if (length(idx0) == 0L) {
    stop("`", arg, "` must name at least one node.", call. = FALSE)
  }
  idx0
}

#' @name .resolve_idx0_mget
#' @keywords internal
.resolve_idx0_mget <- function(session, node_name = NULL, node_index = NULL) {
  if (is.null(node_name) && is.null(node_index)) {
    integer(0)
  } else if (!is.null(node_index)) {
    if (!is.null(node_name)) {
      stop("Pass node names only, not also an index.", call. = FALSE)
    }
    as.integer(node_index - 1L)
  } else if (!is.null(node_name)) {
    rs_indices_of(session, node_name)
  }
}

#' Warn, once per call, about the deprecated `*_index` arguments the caller
#' was given.
#' @keywords internal
#' @noRd
.warn_index_deprecated <- function(env = parent.frame()) {
  args <- grep("_index$", ls(env), value = TRUE)
  used <- args[!vapply(args, function(a) is.null(env[[a]]), logical(1L))]
  if (length(used) > 0L) {
    warning(
      "The `*_index` arguments are deprecated and will be removed in caugi ",
      "2.0.0. Pass node names instead, e.g. `X = nodes(cg)$name[X_index]`. ",
      "Supplied: ",
      paste0("`", used, "`", collapse = ", "),
      ".",
      call. = FALSE
    )
  }
}

#' Validate `max_size` and return it as an integer.
#' @keywords internal
#' @noRd
.check_max_size <- function(max_size) {
  ok <- is.numeric(max_size) &&
    length(max_size) == 1L &&
    is.finite(max_size) &&
    max_size >= 0 &&
    max_size == round(max_size)
  if (!ok) {
    stop("`max_size` must be a single whole number >= 0.", call. = FALSE)
  }
  as.integer(max_size)
}
