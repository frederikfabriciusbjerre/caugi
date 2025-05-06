#' @useDynLib caugi, .registration = TRUE
#' @importFrom cpp11 cpp_register
#' @importFrom tibble tibble as_tibble
#' @importFrom graph nodes edges edgemode
#' @importFrom Matrix sparseMatrix
#' @importFrom rlang is_integerish
NULL

# ─────────────────────────── Public API  ──────────────────────────────────────

#' @title Create a `caugi_graph` object
#'
#' @description Create a `caugi_graph` object from a pair of tibbles, formulas,
#' or a quite flexible infix operator syntax.
#'
#'
#' @param ... Either the classic `nodes, edges` pair *or* any number of
#'            \code{caugi_edge_spec} objects built by infix operators
#'            `%-->%`, `%<->%`, `%---%`, `%o--%`, `%o->%`, or `%o-o%`, or
#'            it can be specified by formulas as (A ~ B, edge_type = "-->") or
#'            alike.
#'
#' @return A `caugi_graph`
#' @export
caugi_graph <- function(...) {
  dots <- rlang::list2(...)

  # two-tibble path
  if (length(dots) == 2 &&
      is.data.frame(dots[[1]]) &&
      "name" %in% names(dots[[1]]) &&
      is.data.frame(dots[[2]]) &&
      all(c("from", "to", "edge_type") %in% names(dots[[2]]))) {
    nodes <- dots[[1]]
    edges <- dots[[2]]
  } else {
    # flexible path
    ## Peel off an optional leading node tibble
    if (length(dots) && is.data.frame(dots[[1]]) &&
        "name" %in% names(dots[[1]])) {
      nodes <- dots[[1]]
      dots <- dots[-1]
    } else {
      nodes <- NULL
    }

    ## Every remaining piece must be *either* a formula *or* edge-spec object
    bad <- !vapply(
      dots, function(x) {
        inherits(x, "caugi_edge_spec") ||
          rlang::is_formula(x, lhs = TRUE)
      },
      logical(1)
    )
    if (any(bad)) {
      stop("All arguments after an optional node tibble must be\n",
           "  * a two-sided formula (A ~ B) or\n",
           "  * an edge spec produced by %-->%, %<->%, %---%, %o--%, %o->%, or %o-o%",
           call. = FALSE
      )
    }

    # formulas to tibble( from, to, edge_type = "-->" )
    parse_formula <- function(fml) {
      lhs <- all.vars(rlang::f_lhs(fml))
      rhs <- all.vars(rlang::f_rhs(fml))
      if (!length(lhs) || !length(rhs)) {
        stop("Formula ", deparse(fml), " must have names both sides.",
             call. = FALSE
        )
      }
      tidyr::crossing(from = lhs, to = rhs) |>
        dplyr::mutate(edge_type = "-->")
    }

    edges_formula <- dplyr::bind_rows(
      lapply(Filter(rlang::is_formula, dots), parse_formula)
    )

    # edge-spec objects are already tibbles
    edges_ops <- dplyr::bind_rows(
      Filter(function(x) inherits(x, "caugi_edge_spec"), dots)
    )

    edges <- dplyr::bind_rows(edges_formula, edges_ops)

    # infer nodes if absent
    if (is.null(nodes)) {
      nodes <- tibble::tibble(name = unique(c(edges$from, edges$to)))
    } else {
      missing <- setdiff(unique(c(edges$from, edges$to)), nodes$name)
      if (length(missing)) {
        stop("Edge list refers to unknown node(s): ",
             paste(missing, collapse = ", "),
             call. = FALSE
        )
      }
    }
  }

  # streamline symmetrical relations
  undirected <- edges$edge_type %in% c("---", "<->", "o-o")
  swap_needed <- undirected & (edges$from > edges$to)

  # swap the from/to columns for undirected edges
  if (any(swap_needed)) {
    edges[swap_needed, c("from", "to")] <-
      edges[swap_needed, c("to", "from")]
  }
  # remove duplicate edges
  edges <- dplyr::distinct(edges,
                           .data$from,
                           .data$to,
                           .data$edge_type,
                           .keep_all = TRUE
  )

  # check edge types
  type_codes <- as.integer(factor(edges$edge_type, levels = edge_type_levels))


  # initialize node ids
  uid <- setNames(seq_len(nrow(nodes)), nodes$name)
  from <- uid[edges$from]
  to <- uid[edges$to]
  if (anyNA(from) | anyNA(to)) {
    stop("from/to must match nodes$name")
  }



  # C++ call
  raw <- caugi_create_csr_from_csr(
    as.integer(from),
    as.integer(to),
    type_codes,
    as.integer(nrow(nodes))
  )
  caugi_graph_from_csr(nodes$name, raw)
}

#' @export
print.caugi_graph <- function(x, ...) {
  print(as_tibble(x, ...))
  invisible(x)
}

# ───────────────────────────── Edge operators  ────────────────────────────────

#' Helper that every operator calls
#'
#' @keywords internal
.build_edge_spec <- function(lhs, rhs, code) {
  tibble::tibble(
    from      = deparse1(lhs),
    to        = deparse1(rhs),
    edge_type = code
  ) |>
    structure(class = c("caugi_edge_spec", "tbl_df", "tbl", "data.frame"))
}

# User-facing operators
`%-->%` <- function(lhs, rhs) .build_edge_spec(substitute(lhs), substitute(rhs), "-->")
`%<->%` <- function(lhs, rhs) .build_edge_spec(substitute(lhs), substitute(rhs), "<->")
`%---%` <- function(lhs, rhs) .build_edge_spec(substitute(lhs), substitute(rhs), "---")
`%o--%` <- function(lhs, rhs) .build_edge_spec(substitute(lhs), substitute(rhs), "o--")
`%o->%` <- function(lhs, rhs) .build_edge_spec(substitute(lhs), substitute(rhs), "o->")
`%o-o%` <- function(lhs, rhs) .build_edge_spec(substitute(lhs), substitute(rhs), "o-o")


# ──────────────────────────────── Helpers  ────────────────────────────────────
#' Reverse edges that are <-- or <-o
#'
#' Swaps the direction for “backwards” edge codes and remaps them to the
#' canonical forward codes. Helper is currently not called elsewhere but kept
#' for completeness.
#'
#' Currently not in use.
#'
#' @param nodes  Tibble of node names (unused, kept for future extensions)
#' @param edges  Tibble with columns `from`, `to`, `edge_type`
#' @return       `edges`, with offending rows fixed in-place
#' @keywords internal
reverse_bad_edges <- function(nodes, edges) {
  # map old reverse codes to canonical + swap
  rev_map <- c(
    "<--" = "-->",
    "<-o" = "o->"
  )
  bad <- edges$edge_type %in% names(rev_map)
  if (any(bad)) {
    swapped <- edges[bad, ]
    edges[bad, c("from", "to")] <- swapped[c("to", "from")]
    edges$edge_type[bad] <- rev_map[swapped$edge_type]
  }
  edges
}


#' Internal helper: wrap a CSR list and node names into a caugi_graph
#' @keywords internal
caugi_graph_from_csr <- function(node_names, ptrs) {
  stopifnot(
    is.character(node_names),
    is.list(ptrs),
    length(ptrs) == 3,
    all(c("row_ptr", "col_ids", "type_codes") %in% names(ptrs)),
    all(sapply(ptrs, is.integer))
  )
  check_edge_integer(ptrs$type_codes)
  structure(
    list(
      nodes = tibble(name = node_names),
      csr = list(
        row_ptr    = as.integer(ptrs$row_ptr),
        col_ids    = as.integer(ptrs$col_ids),
        type_codes = as.integer(ptrs$type_codes)
      )
    ),
    class = "caugi_graph"
  )
}

#' Check if edge type integer maps to edge type
#' @keywords internal
check_edge_integer <- function(x) {
  if (!rlang::is_integerish(x)) {
    stop("Edge integer must be an integer",
         .call = FALSE
    )
  }
  if (any(x < 1L | x > length(edge_type_levels))) {
    stop("Edge integer must be between 1 and ", length(edge_type_levels),
         .call = FALSE
    )
  }
  if (anyNA(x)) {
    stop("Edge integer must not be NA",
         .call = FALSE
    )
  }
  invisible(TRUE)
}
