#' @title Convert a caugi to an igraph object
#'
#' @param x A `caugi` object.
#' @param ... Additional arguments passed to `igraph::graph_from_data_frame()`.
#'
#' @returns An `igraph` object representing the same graph structure.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   class = "DAG"
#' )
#' ig <- as_igraph(cg)
#'
#' @family conversions
#' @concept conversions
#'
#' @export
as_igraph <- function(x, ...) {
  is_caugi(x, throw_error = TRUE)

  if (
    !(x@graph_class %in%
      c("DAG", "PDAG", "MPDAG", "CPDAG", "ADMG", "UG", "AG", "UNKNOWN"))
  ) {
    stop(
      "caugi graphs of class '",
      x@graph_class,
      "' cannot be converted to ",
      "igraph objects.",
      call. = FALSE
    )
  }

  et <- edge_types(x)

  if (x@graph_class == "UG") {
    directed <- FALSE
  } else if (length(et) == 0L) {
    directed <- FALSE
  } else if (all(et %in% c("---", "<->"))) {
    # treat both as undirected
    directed <- FALSE
  } else {
    directed <- TRUE
  }

  # empty graph
  if (nrow(edges(x)) == 0L) {
    return(igraph::graph_from_data_frame(
      data.table::data.table(
        from = character(0),
        to = character(0)
      ),
      vertices = nodes(x),
      directed = directed,
      ...
    ))
  }

  # edge validity for UNKNOWN
  if (x@graph_class == "UNKNOWN") {
    if (any(!(et %in% c("-->", "<->", "---")))) {
      stop(
        "Conversion to igraph is only supported for 'UNKNOWN' caugi graphs ",
        " with '-->', '<->', or '---' edges.",
        call. = FALSE
      )
    }
  }

  e <- edges(x)

  if (!directed) {
    # all undirected
    return(igraph::graph_from_data_frame(
      data.table::data.table(
        from = pmin(e$from, e$to),
        to = pmax(e$from, e$to)
      ),
      vertices = nodes(x),
      directed = FALSE,
      ...
    ))
  } else if (all(et %in% "-->")) {
    # all directed
    return(igraph::graph_from_data_frame(
      data.table::data.table(from = e$from, to = e$to),
      vertices = nodes(x),
      directed = TRUE,
      ...
    ))
  } else {
    # mixed: keep directed as-is, duplicate undirected as bidirected
    dir_df <- e[e$edge == "-->", c("from", "to"), drop = FALSE]

    undir <- e[e$edge %in% c("<->", "---"), c("from", "to"), drop = FALSE]
    u_from <- pmin(undir$from, undir$to)
    u_to <- pmax(undir$from, undir$to)
    undir_fwd <- data.table::data.table(from = u_from, to = u_to)
    undir_rev <- data.table::data.table(from = u_to, to = u_from)
    bi_df <- rbind(undir_fwd, undir_rev)

    all_df <- rbind(
      data.table::data.table(
        from = dir_df$from,
        to = dir_df$to
      ),
      bi_df
    )

    return(igraph::graph_from_data_frame(
      all_df,
      vertices = nodes(x),
      directed = TRUE,
      ...
    ))
  }
}

#' @title Convert a caugi to an adjacency matrix
#'
#' @description
#' With `coding = "binary"` (the default), only supports the edge types found
#' in a PDAG (`-->` and `---`). A `---` edge is written as `1` in both
#' directions, so other symmetric edges such as `<->` are rejected rather than
#' encoded the same way.
#'
#' With `coding = "marks"`, writes `pcalg`'s `amat.pag` coding, which covers
#' `-->`, `<->`, `---`, `o->`, `--o` and `o-o`: `0` no edge, `1` circle, `2`
#' arrowhead, `3` tail, where `m[i, j]` is the mark at node `j` on the edge
#' between `i` and `j`. So `m[i, j] == 2` with `m[j, i] == 3` means `i --> j`.
#' One pair of entries holds one edge, so self-loops and parallel edges are
#' rejected.
#'
#' [as_caugi()] reads both codings back.
#'
#' @param x A `caugi` object.
#' @param coding Either `"binary"` for a 0/1 adjacency matrix or `"marks"`
#'   for the mark-coded `amat.pag` form.
#'
#' @returns An integer matrix with row/col names.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   class = "DAG"
#' )
#' adj <- as_adjacency(cg)
#'
#' # Edges with circle or bidirected endpoints need the mark coding.
#' g <- caugi(A %o->% B, B %<->% C, class = "UNKNOWN")
#' m <- as_adjacency(g, coding = "marks")
#' m
#' as_caugi(m, class = "UNKNOWN")
#'
#' @family conversions
#' @concept conversions
#'
#' @export
as_adjacency <- function(x, coding = c("binary", "marks")) {
  is_caugi(x, throw_error = TRUE)
  coding <- match.arg(coding)

  nm <- nodes(x)$name
  n <- length(nm)
  out <- matrix(0L, n, n, dimnames = list(nm, nm))

  e <- edges(x)
  if (nrow(e) == 0L) {
    return(out)
  }

  if (coding == "marks") {
    # Marks at the `from` and `to` node of each glyph.
    marks <- rbind(
      "-->" = c(3L, 2L),
      "<->" = c(2L, 2L),
      "---" = c(3L, 3L),
      "o->" = c(1L, 2L),
      "--o" = c(3L, 1L),
      "o-o" = c(1L, 1L)
    )
    unknown <- setdiff(e$edge, rownames(marks))
    if (length(unknown) > 0L) {
      stop(
        "Unsupported edge glyphs in conversion to a mark-coded matrix: ",
        paste(unknown, collapse = ", "),
        call. = FALSE
      )
    }
    i <- match(e$from, nm)
    j <- match(e$to, nm)
    if (any(i == j) || anyDuplicated(paste(pmin(i, j), pmax(i, j)))) {
      stop(
        "A mark-coded matrix holds one edge per pair of distinct nodes, ",
        "so self-loops and parallel edges cannot be converted.",
        call. = FALSE
      )
    }
    m <- marks[e$edge, , drop = FALSE]
    out[cbind(i, j)] <- m[, 2L]
    out[cbind(j, i)] <- m[, 1L]
    return(out)
  }

  ok <- e$edge %in% c("-->", "---")
  if (any(!ok)) {
    stop(
      "Unsupported edge glyphs in conversion to adjacency: ",
      paste(unique(e$edge[!ok]), collapse = ", "),
      call. = FALSE
    )
  }

  i <- match(e$from, nm)
  j <- match(e$to, nm)

  dir_ix <- e$edge %in% c("-->")
  if (any(dir_ix)) {
    out[cbind(i[dir_ix], j[dir_ix])] <- 1L
  }

  # Undirected edges: symmetric entries
  und_ix <- e$edge %in% c("---")
  if (any(und_ix)) {
    iu <- i[und_ix]
    ju <- j[und_ix]
    out[cbind(iu, ju)] <- 1L
    out[cbind(ju, iu)] <- 1L
  }

  out
}

#' @title Convert a caugi to a bnlearn network
#'
#' @param x A `caugi` object.
#'
#' @returns A `bnlearn` DAG.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   class = "DAG"
#' )
#' g_bn <- as_bnlearn(cg)
#'
#' @family conversions
#' @concept conversions
#'
#' @export
as_bnlearn <- function(x) {
  is_caugi(x, throw_error = TRUE)

  if (x@graph_class != "DAG") {
    stop("as_bnlearn requires a 'DAG' graph_class.", call. = FALSE)
  }

  nm <- nodes(x)$name
  e <- edges(x)

  g <- bnlearn::empty.graph(nm)
  if (nrow(e) == 0L) {
    return(g)
  }

  A <- as.matrix(e[, c("from", "to")])
  colnames(A) <- c("from", "to")
  bnlearn::arcs(g) <- A
  g
}

#' @title Convert a caugi to a dagitty graph
#'
#' @details
#' The dagitty graph type is `dag`, `pdag`, `mag` or `pag`, picked from the
#' edge types. Node names are always quoted, so they may contain spaces or
#' edge symbols, with a few limits:
#' * dagitty rejects nodes named `node` or `graph`, so these raise an error.
#' * A `"` in a name is escaped. Backslashes are passed through as is, since
#'   dagitty keeps `\\` as two characters, so a name that ends in a backslash
#'   can't be written.
#'
#' Reading a `pag` back with [as_caugi()] gives class `"UNKNOWN"`, as caugi
#' doesn't support PAGs yet.
#'
#' @param x A `caugi` object.
#'
#' @returns A `dagitty` object.
#'
#' @examples
#' cg <- caugi(
#'   A %-->% B,
#'   class = "DAG"
#' )
#' g_dg <- as_dagitty(cg)
#'
#' @family conversions
#' @concept conversions
#'
#' @export
as_dagitty <- function(x) {
  is_caugi(x, throw_error = TRUE)

  nm <- nodes(x)$name
  e <- edges(x)

  reserved <- intersect(nm, c("node", "graph"))
  if (length(reserved) > 0L) {
    stop(
      "dagitty does not allow nodes named ",
      paste0("'", reserved, "'", collapse = " or "),
      ".",
      call. = FALSE
    )
  }
  # dagitty unescapes `\"` but keeps `\\` as two characters, so only `"` is
  # escaped and backslashes are passed through as is.
  quote_name <- function(s) sprintf('"%s"', gsub('"', '\\"', s, fixed = TRUE))

  if (nrow(e) == 0L) {
    spec <- paste0("dag { ", paste(quote_name(nm), collapse = " ; "), " }")
    return(dagitty::dagitty(spec))
  }

  gs <- unique(e$edge)
  type <-
    if (all(gs %in% "-->")) {
      "dag"
    } else if (all(gs %in% c("-->", "---"))) {
      # DAG + undirected
      "pdag"
    } else if (all(gs %in% c("-->", "---", "<->"))) {
      # DAG + bidirected
      "mag"
    } else {
      # any circle marks present
      "pag"
    }

  map_edge <- function(g, a, b) {
    switch(
      g,
      "-->" = sprintf("%s -> %s", a, b),
      "<->" = {
        aa <- min(a, b)
        bb <- max(a, b)
        sprintf("%s <-> %s", aa, bb)
      },
      "---" = {
        aa <- min(a, b)
        bb <- max(a, b)
        sprintf("%s -- %s", aa, bb)
      },
      "o->" = sprintf("%s @-> %s", a, b),
      "o-o" = {
        aa <- min(a, b)
        bb <- max(a, b)
        sprintf("%s @-@ %s", aa, bb)
      },
      "--o" = sprintf("%s @-- %s", b, a),
      stop("Unsupported edge type for dagitty: ", g, call. = FALSE)
    )
  }

  es <- mapply(
    map_edge,
    e$edge,
    quote_name(e$from),
    quote_name(e$to),
    USE.NAMES = FALSE
  )
  es <- unique(es)

  decl <- paste(quote_name(nm), collapse = " ; ")
  body <- paste(c(decl, es), collapse = " ; ")
  dagitty::dagitty(sprintf("%s { %s }", type, body))
}
