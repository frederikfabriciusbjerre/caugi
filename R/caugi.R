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
#' @param state For internal use. Build a graph by supplying a pre-constructed
#' state environment.
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
    `.state` = S7::new_property(S7::class_environment),
    nodes = S7::new_property(
      S7::class_any,
      getter = function(self) self@`.state`$nodes,
      setter = function(self, value) {
        stop(
          "nodes is read-only via @ <-. ",
          "Use `add_nodes()` or `remove_nodes()` instead. ",
          "Advanced users can modify `cg@.state$nodes` directly, ",
          "but this is not recommended.",
          call. = FALSE
        )
      }
    ),
    edges = S7::new_property(
      S7::class_any,
      getter = function(self) self@`.state`$edges,
      setter = function(self, value) {
        stop(
          "`edges` property is read-only via @ <-. ",
          "Use `add_edges()` or `remove_edges()` instead. ",
          "Advanced users can modify `cg@.state$edges` directly ",
          "but this is not recommended.",
          call. = FALSE
        )
      }
    ),
    ptr = S7::new_property(
      S7::class_any,
      getter = function(self) {
        # Derive ptr from session - triggers lazy compilation if needed
        session <- self@`.state`$session
        if (is.null(session)) {
          return(NULL)
        }
        graph_session_view_ptr(session)
      },
      setter = function(self, value) {
        stop(
          "`ptr` property is read-only via @ <-. ",
          "The pointer is managed by the session.",
          call. = FALSE
        )
      }
    ),
    simple = S7::new_property(
      S7::class_logical,
      getter = function(self) self@`.state`$simple
    ),
    graph_class = S7::new_property(
      S7::class_character,
      getter = function(self) self@`.state`$class,
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
        return(self@`.state`$name_index_map)
      },
      setter = function(self, value) {
        stop(
          "`name_index_map` property is read-only via @ <-. ",
          "It is managed internally.",
          call. = FALSE
        )
      }
    ),
    session = S7::new_property(
      S7::class_any,
      getter = function(self) {
        return(self@`.state`$session)
      },
      setter = function(self, value) {
        stop(
          "`session` property is read-only via @ <-. ",
          "It is managed internally by the Rust backend.",
          call. = FALSE
        )
      }
    )
  ),
  validator = function(self) {
    s <- self@`.state`
    # Allow simple = FALSE for UNKNOWN, ADMG, and AG (mixed edges can share pairs)
    if (
      isFALSE(s$simple) &&
        !identical(s$class, "UNKNOWN") &&
        !identical(s$class, "ADMG") &&
        !identical(s$class, "AG")
    ) {
      return("If simple = FALSE, class must be 'UNKNOWN', 'ADMG', or 'AG'")
    }

    # Validate session exists for non-empty graphs
    if (is.null(s$session) && nrow(s$nodes) > 0L) {
      return("Internal error: session is NULL for non-empty graph.")
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
    class = c("AUTO", "DAG", "UG", "PDAG", "ADMG", "AG", "UNKNOWN"),
    state = NULL
  ) {
    if (!is.null(state)) {
      return(S7::new_object(
        caugi,
        `.state` = state
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

    # initialize fastmap for name to index mapping
    name_index_map <- fastmap::fastmap()
    if (n > 0L) {
      do.call(
        name_index_map$mset,
        .set_names(as.list(seq_len(n) - 1L), nodes$name)
      )
    }

    # Create GraphSession - the canonical Rust state
    # Session handles lazy compilation and caching internally
    session <- NULL
    if (n > 0L) {
      # Validate and resolve class using the builder (this ensures type safety)
      # The builder validates edge types and class compatibility
      b <- graph_builder_new(reg, n = n, simple = simple)
      if (nrow(edges) > 0L) {
        codes <- edge_registry_code_of(reg, edges$edge)
        graph_builder_add_edges(
          b,
          as.integer(unname(id[edges$from])),
          as.integer(unname(id[edges$to])),
          as.integer(codes)
        )
      }
      # This validates that edges are compatible with the class
      ptr <- graph_builder_build_view(b, class)
      resolved_class <- graph_class_ptr(ptr)

      # Now create session with the validated/resolved class
      session <- graph_session_new(reg, n, simple, resolved_class)
      graph_session_set_names(session, nodes$name)

      if (nrow(edges) > 0L) {
        graph_session_set_edges(
          session,
          as.integer(unname(id[edges$from])),
          as.integer(unname(id[edges$to])),
          as.integer(codes)
        )
      }

      class <- resolved_class
    }

    state <- .cg_state(
      nodes = nodes,
      edges = edges,
      simple = simple,
      class = class,
      name_index_map = name_index_map,
      session = session
    )

    S7::new_object(
      caugi,
      `.state` = state
    )
  }
)

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Helpers ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Convert a graph pointer to a `caugi` S7 object
#'
#' @description Convert a graph pointer from Rust to a `caugi` to a
#' S7 object.
#'
#' @param ptr A pointer to the underlying Rust graph structure.
#' @param node_names Optional character vector of node names. If `NULL`
#' (default), nodes will be named `V1`, `V2`, ..., `Vn`.
#'
#' @returns A `caugi` object representing the graph.
#'
#' @keywords internal
.view_to_caugi <- function(ptr, node_names = NULL) {

  if (is.null(ptr)) {
    stop("ptr is NULL", call. = FALSE)
  }

  n <- n_ptr(ptr)
  if (is.null(node_names)) {
    node_names <- sprintf("V%d", seq_len(n))
  }
  if (length(node_names) != n) {
    stop("length(node_names) must equal n_ptr(ptr)", call. = FALSE)
  }

  edges_idx <- edges_ptr_df(ptr)

  if (length(edges_idx$from0) == 0L) {
    edges_tbl <- .edge_constructor()
  } else {
    edges_tbl <- .edge_constructor_idx(
      from_idx = edges_idx$from0 + 1L,
      edge = as.character(edges_idx$glyph),
      to_idx = edges_idx$to0 + 1L,
      node_names = node_names
    )
  }

  nodes_tbl <- .node_constructor(names = node_names)

  name_index_map <- fastmap::fastmap()
  do.call(
    name_index_map$mset,
    .set_names(
      as.list(seq_len(n) - 1L),
      node_names
    )
  )

  simple <- is_simple_ptr(ptr)
  class <- graph_class_ptr(ptr)

  # Create a new session and populate it with the graph data
  reg <- caugi_registry()
  session <- graph_session_new(reg, n, simple, class)
  graph_session_set_names(session, node_names)

  if (nrow(edges_tbl) > 0L) {
    id <- seq_len(n) - 1L
    names(id) <- node_names
    codes <- edge_registry_code_of(reg, edges_tbl$edge)
    graph_session_set_edges(
      session,
      as.integer(unname(id[edges_tbl$from])),
      as.integer(unname(id[edges_tbl$to])),
      as.integer(codes)
    )
  }

  state <- .cg_state(
    nodes = nodes_tbl,
    edges = edges_tbl,
    simple = simple,
    class = class,
    name_index_map = name_index_map,
    session = session
  )
  caugi(state = state)
}

#' @title Create the state environment for a `caugi` (internal)
#'
#' @description Internal function to create the state environment for a
#' `caugi`. This function is not intended to be used directly by users.
#'
#' @param nodes A `data.table` of nodes with a `name` column.
#' @param edges A `data.table` of edges with `from`, `edge`, and `to` columns.
#' @param simple Logical; whether the graph is simple
#' (no parallel edges or self-loops).
#' @param class Character; one of `"UNKNOWN"`, `"DAG"`, `"UG"`, `"PDAG"`, `"ADMG"`, or `"AG"`.
#' @param name_index_map A `fastmap` mapping node names to their zero indexed
#' indices.
#' @param session A pointer to the GraphSession Rust object. This is the
#' canonical Rust state that handles lazy compilation and caching.
#'
#' @returns An environment containing the graph state.
#'
#' @keywords internal
.cg_state <- function(
  nodes,
  edges,
  simple,
  class,
  name_index_map,
  session
) {
  e <- new.env(parent = emptyenv())
  e$nodes <- nodes
  e$edges <- edges
  e$simple <- isTRUE(simple)
  e$class <- class
  e$name_index_map <- name_index_map
  e$session <- session
  e
}
