# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── caugi graph API ────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' Create a `caugi` from edge expressions.
#'
#' @description Create a `caugi` from a series of edge expressions using
#' infix operators. Nodes can be specified as symbols, strings, or numbers.
#'
#' The following edge operators are supported by default:
#' * `%-->%` for directed edges (A --> B)
#' * `%---%` for undirected edges (A --- B)
#' * `%<->%` for bidirected edges (A <-> B)
#' * `%o->%` for partially directed edges (A o-> B)
#' * `%--o%` for partially undirected edges (A --o B)
#' * `%o-o%` for partial edges (A o-o B)
#'
#' You can register additional edge types using [register_caugi_edge()].
#'
#' @param ... Edge expressions using the supported infix operators, or
#' nodes given by symbols or strings. Multiple edges can be
#' combined using `+`: `A --> B + C`, indicating an edge from `A` to both `B`
#' and `C`. Nodes can also be grouped using `c(...)` or parentheses.
#' @param from Character vector of source node names.
#' Optional; mutually exclusive with `...`.
#' @param edge Character vector of edge types.
#' Optional; mutually exclusive with `...`.
#' @param to Character vector of target node names.
#' Optional; mutually exclusive with `...`.
#' @param nodes Character vector of node names to declare as isolated nodes.
#' An optional, but recommended, option is to provide all node names in the
#' graph, including those that appear in edges. If `nodes` is provided, the
#' order of nodes in the graph will follow the order in `nodes`.
#' @param edges_df Optional data.frame or data.table with columns
#' `from`, `edge`, and `to` to specify edges. Mutually exclusive with `...`
#' and `from`, `edge`, `to`. Can be used to create graphs using `edges(cg)`
#' from another `caugi` object, `cg`.
#' @param simple Logical; if `TRUE` (default), the graph is a simple graph, and
#' the function will throw an error if the input contains parallel edges or
#' self-loops.
#' @param class Character; one of `"AUTO"`, `"DAG"`, `"UG"`, `"PDAG"`, `"ADMG"`,
#' `"AG"`, or `"UNKNOWN"`. `"AUTO"` will automatically pick the appropriate
#' class based on the first match in the order of `"DAG"`, `"UG"`, `"PDAG"`,
#' `"ADMG"`, and `"AG"`.
#' It will default to `"UNKNOWN"` if no match is found.
#' @param .session For internal use. Build a graph by supplying a
#' pre-constructed session pointer from Rust.
#' @param build Deprecated.
#' @param state Deprecated. Replaced by `.session`.
#'
#' @returns A `caugi` S7 object containing the nodes, edges, and a
#' pointer to the underlying Rust graph structure.
#'
#' @examples
#' # create a simple DAG (using NSE)
#' cg <- caugi(
#'   A %-->% B + C,
#'   B %-->% D,
#'   class = "DAG"
#' )
#'
#' # create a PDAG with undirected edges (using NSE)
#' cg2 <- caugi(
#'   A %-->% B + C,
#'   B %---% D,
#'   E, # no neighbors for this node
#'   class = "PDAG"
#' )
#'
#' # create a DAG (using SE)
#' cg3 <- caugi(
#'   from = c("A", "A", "B"),
#'   edge = c("-->", "-->", "-->"),
#'   to = c("B", "C", "D"),
#'   nodes = c("A", "B", "C", "D", "E"),
#'   class = "DAG"
#' )
#'
#' # create a non-simple graph
#' cg4 <- caugi(
#'   A %-->% B,
#'   B %-->% A,
#'   class = "UNKNOWN",
#'   simple = FALSE
#' )
#'
#' cg4@simple # FALSE
#' cg4@graph_class # "UNKNOWN"
#'
#' @family caugi
#' @concept caugi
#'
#' @export
caugi <- S7::new_class(
  "caugi",
  parent = S7::S7_object,
  properties = list(
    session = S7::new_property(
      S7::class_any,
      setter = function(self, value) {
        if (isTRUE(get0("constructing_session", .caugi_env))) {
          attr(self, "session") <- value
          return(self)
        }
        stop(
          "session is read-only via @ <-. ",
          "Use `caugi()` to create a new graph.",
          call. = FALSE
        )
      }
    ),
    nodes = S7::new_property(
      S7::class_any,
      getter = function(self) {
        .node_constructor(names = rs_names(self@session))
      },
      setter = function(self, value) {
        stop(
          "nodes is read-only via @ <-. ",
          "Use `add_nodes()` or `remove_nodes()` instead.",
          call. = FALSE
        )
      }
    ),
    edges = S7::new_property(
      S7::class_any,
      getter = function(self) {
        .build_edges_from_session(self@session)
      },
      setter = function(self, value) {
        stop(
          "`edges` property is read-only via @ <-. ",
          "Use `add_edges()` or `remove_edges()` instead.",
          call. = FALSE
        )
      }
    ),
    ptr = S7::new_property(
      S7::class_any,
      getter = function(self) {
        .deprecated_field_warning(
          "`@ptr` is deprecated. Use `@session` instead."
        )
        NULL
      },
      setter = function(self, value) {
        .deprecated_field_warning(
          "`@ptr` is deprecated. Use `@session` instead."
        )
        stop(
          "`ptr` property is read-only via @ <-.",
          call. = FALSE
        )
      }
    ),
    simple = S7::new_property(
      S7::class_logical,
      getter = function(self) {
        rs_simple(self@session)
      }
    ),
    built = S7::new_property(
      S7::class_any,
      getter = function(self) {
        .deprecated_field_warning(
          "`@built` is deprecated. The graph is always built lazily."
        )
        NULL
      },
      setter = function(self, value) {
        .deprecated_field_warning(
          "`@built` is deprecated. The graph is always built lazily."
        )
        stop(
          "`built` property is read-only via @ <-.",
          call. = FALSE
        )
      }
    ),
    graph_class = S7::new_property(
      S7::class_character,
      getter = function(self) {
        rs_class(self@session)
      },
      setter = function(self, value) {
        stop(
          "`graph_class` property is read-only via @ <-. ",
          "It should only be set at construction.",
          call. = FALSE
        )
      }
    ),
    name_index_map = S7::new_property(
      S7::class_any,
      getter = function(self) {
        .deprecated_field_warning("`@name_index_map` is deprecated.")
        NULL
      },
      setter = function(self, value) {
        .deprecated_field_warning("`@name_index_map` is deprecated.")
        stop(
          "`name_index_map` property is read-only via @ <-.",
          call. = FALSE
        )
      }
    ),
    `.state` = S7::new_property(
      S7::class_any,
      getter = function(self) {
        .deprecated_field_warning("`@.state` is deprecated.")
        NULL
      },
      setter = function(self, value) {
        .deprecated_field_warning("`@.state` is deprecated.")
        stop(
          "`.state` property is read-only via @ <-.",
          call. = FALSE
        )
      }
    )
  ),
  validator = function(self) {
    # Allow simple = FALSE for UNKNOWN, ADMG, and AG (mixed edges can share pairs)
    simple <- rs_simple(self@session)
    class <- rs_class(self@session)
    if (
      isFALSE(simple) &&
        !identical(class, "UNKNOWN") &&
        !identical(class, "ADMG") &&
        !identical(class, "AG")
    ) {
      return("If simple = FALSE, class must be 'UNKNOWN', 'ADMG', or 'AG'")
    }

    NULL
  },
  constructor = function(
    ...,
    from = NULL,
    edge = NULL,
    to = NULL,
    nodes = NULL,
    edges_df = NULL,
    simple = TRUE,
    build = NULL, # deprecated
    class = c("AUTO", "DAG", "UG", "PDAG", "ADMG", "AG", "UNKNOWN"),
    state = NULL, # deprecated
    .session = NULL
  ) {
    if (!missing(build)) {
      warning(
        "`build` is deprecated. Graph sessions are always created lazily.",
        call. = FALSE
      )
    }

    if (!is.null(state)) {
      warning(
        "`state` is deprecated and ignored.",
        call. = FALSE
      )
    }

    if (!is.null(.session)) {
      .caugi_env$constructing_session <- TRUE
      on.exit(
        {
          .caugi_env$constructing_session <- FALSE
        },
        add = TRUE
      )
      return(S7::new_object(
        caugi,
        session = .session
      ))
    }
    class <- toupper(class)
    class <- match.arg(class)

    calls <- as.list(substitute(list(...)))[-1L]
    has_expr <- length(calls) > 0L
    has_vec <- !(is.null(from) && is.null(edge) && is.null(to))
    has_df <- !is.null(edges_df)
    if (has_df) {
      if (!is.data.frame(edges_df)) {
        stop("`edges_df` must be a data.frame or data.table.", call. = FALSE)
      }
      required_cols <- c("from", "edge", "to")
      if (!all(required_cols %chin% colnames(edges_df))) {
        stop(
          "`edges_df` must contain columns: ",
          paste(required_cols, collapse = ", "),
          ".",
          call. = FALSE
        )
      }
      if (has_expr) {
        stop(
          "Provide edges via infix expressions in `...` or ",
          "via `edges_df`, but not both.",
          call. = FALSE
        )
      }
      if (has_vec) {
        stop(
          "Provide edges via `edges_df` or via `from`, `edge`, `to`, ",
          "but not both.",
          call. = FALSE
        )
      }
      if (nrow(edges_df) == 0L) {
        from <- character(0)
        edge <- character(0)
        to <- character(0)
      } else {
        from <- as.character(edges_df$from)
        edge <- as.character(edges_df$edge)
        to <- as.character(edges_df$to)
      }

      has_vec <- TRUE
    }

    if (has_vec) {
      if (is.null(from) || is.null(edge) || is.null(to)) {
        stop(
          "`from`, `edge`, and `to` must all be provided.",
          call. = FALSE
        )
      }
      if (!(is.character(from) && is.character(edge) && is.character(to))) {
        stop(
          "`from`, `edge`, and `to` must all be character vectors.",
          call. = FALSE
        )
      }
      if (!(length(from) == length(edge) && length(edge) == length(to))) {
        stop(
          "`from`, `edge`, and `to` must be equal length.",
          call. = FALSE
        )
      }
    }

    if (has_expr && has_vec) {
      stop(
        "Provide edges via infix expressions in `...` or ",
        "via `from`, `edge`, `to`, but not both.",
        call. = FALSE
      )
    }

    if (!is.null(nodes)) {
      if (!is.character(nodes)) {
        if (is.data.frame(nodes) && "name" %in% colnames(nodes)) {
          nodes <- as.character(nodes$name)
        } else {
          stop(
            "`nodes` must be a character vector of node names.",
            call. = FALSE
          )
        }
      }
    }

    # Allow simple = FALSE for UNKNOWN, ADMG, and AG (mixed edges can share pairs)
    if (!simple && class != "UNKNOWN" && class != "ADMG" && class != "AG") {
      stop(
        "If simple = FALSE, class must be 'UNKNOWN', 'ADMG', or 'AG'",
        call. = FALSE
      )
    }

    # Parse into edges + declared nodes
    if (has_expr) {
      terms <- .collect_edges_nodes(calls)
      edges <- terms$edges
      declared <- terms$declared
      if (!is.null(nodes)) {
        edge_node_names <- unique(c(edges$from, edges$to))
        if (all(edge_node_names %in% nodes)) {
          # declared nodes contain all edge nodes: preserve their order
          declared <- nodes
        } else {
          # use edge order first, then add declared isolates
          declared <- unique(c(edge_node_names, nodes))
        }
        declared <- unique(c(declared, nodes))
      }
    } else if (has_vec) {
      edges <- .edge_constructor(from = from, edge = edge, to = to)
      declared <- nodes
    } else {
      edges <- .edge_constructor()
      declared <- nodes
    }

    edge_node_names <- unique(c(edges$from, edges$to))
    if (length(declared) > 0L && all(edge_node_names %in% declared)) {
      # Declared contains all edge nodes: preserve declared order
      all_node_names <- unique(declared)
    } else if (length(declared) > 0L) {
      # use edge order first, then add declared isolates
      all_node_names <- unique(c(edge_node_names, declared))
    } else {
      # No declared nodes: use edge order
      all_node_names <- edge_node_names
    }
    nodes <- data.table::data.table(name = all_node_names)
    n <- nrow(nodes)
    id <- seq_len(n) - 1L
    names(id) <- nodes$name

    # Initialize caugi registry (if not already registered)
    reg <- caugi_registry()

    # Create GraphSession - the canonical Rust state
    # Session handles lazy compilation and caching internally
    # Always create a session, even for empty graphs (n = 0)
    resolved_class <- class
    session <- rs_new(reg, n, simple, class)

    if (n > 0L) {
      rs_set_names(session, nodes$name)
    }

    if (n > 0L && nrow(edges) > 0L) {
      codes <- edge_registry_code_of(reg, edges$edge)
      rs_set_edges(
        session,
        as.integer(unname(id[edges$from])),
        as.integer(unname(id[edges$to])),
        as.integer(codes)
      )
      # Validate and resolve class using the session (name-aware errors)
      resolved_class <- rs_resolve_class(session, class)
    } else if (class == "AUTO") {
      # For empty graphs with AUTO, default to DAG
      resolved_class <- "DAG"
    }

    if (!identical(resolved_class, class)) {
      rs_set_class(session, resolved_class)
    }

    .caugi_env$constructing_session <- TRUE
    on.exit(
      {
        .caugi_env$constructing_session <- FALSE
      },
      add = TRUE
    )

    S7::new_object(
      caugi,
      session = session
    )
  }
)

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Helpers ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Convert a graph session to a `caugi` S7 object
#'
#' @description Convert a graph pointer from Rust to a `caugi` to a
#' S7 object.
#'
#' @param session A pointer to the underlying Rust GraphSession.
#' @param node_names Optional character vector of node names. If `NULL`
#' (default), node names will be taken from the session.
#'
#' @returns A `caugi` object representing the graph.
#'
#' @keywords internal
.session_to_caugi <- function(session, node_names = NULL) {
  if (is.null(session)) {
    stop("session is NULL", call. = FALSE)
  }

  n <- rs_n(session)
  if (is.null(node_names)) {
    node_names <- rs_names(session)
  }
  if (length(node_names) != n) {
    stop(
      "length(node_names) must equal rs_n(session)",
      call. = FALSE
    )
  }

  # Ensure session has the correct names
  rs_set_names(session, node_names)

  caugi(.session = session)
}

#' @title Build edges data.table from session
#'
#' @description Internal helper to build edges data.table from Rust session.
#'
#' @param session A pointer to the GraphSession Rust object.
#'
#' @returns A `data.table` with columns `from`, `edge`, and `to`.
#'
#' @keywords internal
.build_edges_from_session <- function(session) {
  edges_idx <- rs_edges_df(session)
  if (length(edges_idx$from0) == 0L) {
    return(.edge_constructor())
  }
  node_names <- rs_names(session)
  .edge_constructor_idx(
    from_idx = edges_idx$from0 + 1L,
    edge = as.character(edges_idx$glyph),
    to_idx = edges_idx$to0 + 1L,
    node_names = node_names
  )
}

#' @title Suppress field warning
#'
#' @description Internal helper to suppress field warning.
#'
#' @returns A logical value indicating whether the field
#' warning should be suppressed.
#'
#' @keywords internal
#' @noRd
.supress_field_warning <- function() {
  calls <- sys.calls()
  if (length(calls) == 0L) {
    return(FALSE)
  }

  call_text <- vapply(
    calls,
    function(cl) paste(deparse(cl, nlines = 1L), collapse = ""),
    character(1)
  )

  # Top-level task callbacks execute through an internal `cb(...)` frame.
  any(grepl("^cb\\(expr, value, (ok|succeeded), visible\\)$", call_text))
}

.deprecated_field_warning <- function(message) {
  if (!.supress_field_warning()) {
    warning(message, call. = FALSE)
  }
}
