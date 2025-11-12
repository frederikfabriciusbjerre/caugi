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
#' @param simple Logical; if `TRUE` (default), the graph is a simple graph, and
#' the function will throw an error if the input contains parallel edges or
#' self-loops.
#' @param build Logical; if `TRUE` (default), the graph will be built using the
#' Rust backend. If `FALSE`, the graph will not be built, and the Rust backend
#' cannot be used. The graph will build, when queries are made to the graph or
#' if calling [build()]. __Note__: Even if `build = TRUE`, if no edges or
#' nodes are provided, the graph will not be built and the pointer will be
#' `NULL`.
#' @param class Character; one of `"UNKNOWN"`, `"DAG"`, `"PDAG"`, or `"UG"`.
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
#' cg4@built # TRUE
#' cg4@graph_class # "UNKNOWN"
#'
#' # create graph, but don't built Rust object yet, which is needed for queries
#' cg5 <- caugi(
#'   A %-->% B + C,
#'   B %-->% D,
#'   class = "DAG",
#'   build = FALSE
#' )
#'
#' cg@built # FALSE
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
        stop("nodes is read-only via @ <-. ",
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
        stop("`edges` properrt is read-only via @ <-. ",
          "Use `add_edges()` or `remove_edges()` instead. ",
          "Advanced users can modify `cg@.state$edges` directly ",
          "but this is not recommended.",
          call. = FALSE
        )
      }
    ),
    ptr = S7::new_property(
      S7::class_any,
      getter = function(self) self@`.state`$ptr,
      setter = function(self, value) {
        stop("`ptr` property is read-only via @ <-. ",
          "Use `build()` to (re)build the graph.",
          call. = FALSE
        )
      }
    ),
    simple = S7::new_property(
      S7::class_logical,
      getter = function(self) {
        # we would like to return the Rust state if built
        if (is.null(self@ptr)) {
          return(self@`.state`$simple)
        }
        # extra precuation
        if (self@`.state`$simple != is_simple_ptr(self@ptr)) {
          stop(paste0(
            "Internal warning: graph simplicity mismatch between R (",
            self@`.state`$simple, ") and Rust (", is_simple_ptr(self@ptr),
            "). ",
            "Please report this issue."
          ), call. = FALSE)
        }
        is_simple_ptr(self@ptr)
      }
    ),
    built = S7::new_property(
      S7::class_logical,
      getter = function(self) self@`.state`$built,
      setter = function(self, value) {
        stop("`built` property is read-only via @ <-. ",
          "It should only be set at construction or when calling `build()`.",
          call. = FALSE
        )
      }
    ),
    graph_class = S7::new_property(
      S7::class_character,
      getter = function(self) {
        # we would like to return the Rust state if built
        if (is.null(self@ptr)) {
          return(self@`.state`$class)
        }
        # extra precuation
        if (toupper(self@`.state`$class) != toupper(graph_class_ptr(self@ptr))) {
          stop(paste0(
            "Internal warning: graph class mismatch between R (",
            self@`.state`$class, ") and Rust (", graph_class_ptr(self@ptr),
            "). ",
            "Please report this issue."
          ), call. = FALSE)
        }
        graph_class_ptr(self@ptr)
      },
      setter = function(self, value) {
        stop("`graph_class` property is read-only via @ <-. ",
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
        stop("`name_index_map` property is read-only via @ <-. ",
          "It is managed internally.",
          call. = FALSE
        )
      }
    )
  ),
  validator = function(self) {
    s <- self@`.state`
    if (isFALSE(s$simple) && !identical(s$class, "UNKNOWN")) {
      return("If simple = FALSE, class must be 'UNKNOWN'")
    }

    if (is.null(self@ptr) && s$built) {
      return(paste0(
        "Internal error: graph pointer is NULL but built = TRUE. ",
        "Please report this issue."
      ))
    }

    # if the graph has been built and the pointer exists, check consistency
    if (!is.null(self@ptr) && s$built) {
      if (toupper(graph_class_ptr(self@ptr)) != toupper(s$class)) {
        return(paste0(
          "Internal error: graph class mismatch between R (", s$class,
          ") and Rust (", graph_class_ptr(self@ptr), "). ",
          "Please report this issue."
        ))
      }
      if (is_simple_ptr(self@ptr) != s$simple) {
        return(paste0(
          "Internal error: graph simplicity mismatch between R (", s$simple,
          ") and Rust (", is_simple_ptr(self@ptr), "). ",
          "Please report this issue."
        ))
      }
    }

    # todo: how may a user corrupt via setting cg@.state$field <- value?
    NULL
  },
  constructor = function(...,
                         from = NULL, edge = NULL, to = NULL, nodes = NULL,
                         simple = TRUE,
                         build = TRUE,
                         class = c("UNKNOWN", "DAG", "PDAG", "UG"),
                         state = NULL) {
    if (!is.null(state)) {
      return(S7::new_object(
        caugi,
        `.state` = .freeze_state(state)
      ))
    }
    class <- toupper(class)
    class <- match.arg(class)

    calls <- as.list(substitute(list(...)))[-1L]
    has_expr <- length(calls) > 0L
    has_vec <- !(is.null(from) && is.null(edge) && is.null(to))
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
          stop("`nodes` must be a character vector of node names.",
            call. = FALSE
          )
        }
      }
    }

    if (!simple && class != "UNKNOWN") {
      stop("If simple = FALSE, class must be 'UNKNOWN'", call. = FALSE)
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
      if (build == TRUE && !missing(build)) {
        warning("No edges or nodes provided; graph will not be built.",
          call. = FALSE
        )
      }
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

    # Initialize graph pointer and built flag
    gptr <- NULL
    built <- FALSE

    # Build the graph using the Rust backend
    if (build && n > 0L) {
      b <- graph_builder_new(reg, n = n, simple = simple)

      if (nrow(edges)) {
        codes <- edge_registry_code_of(reg, edges$edge)
        graph_builder_add_edges(
          b,
          as.integer(unname(id[edges$from])),
          as.integer(unname(id[edges$to])),
          as.integer(codes)
        )
      }

      gptr <- graph_builder_build_view(b, class)
      built <- TRUE
    }

    # initialize fastmap for name to index mapping
    name_index_map <- fastmap::fastmap()
    do.call(
      name_index_map$mset,
      .set_names(as.list(seq_len(nrow(nodes)) - 1L), nodes$name)
    )

    state <- .cg_state(
      nodes = nodes,
      edges = edges,
      ptr = gptr,
      built = built,
      simple = simple,
      class = class,
      name_index_map = name_index_map
    )

    S7::new_object(
      caugi,
      `.state` = .freeze_state(state)
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
  if (is.null(ptr)) stop("ptr is NULL", call. = FALSE)

  n <- n_ptr(ptr)
  if (is.null(node_names)) node_names <- sprintf("V%d", seq_len(n))
  if (length(node_names) != n) {
    stop("length(node_names) must equal n_ptr(ptr)",
      call. = FALSE
    )
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
  do.call(name_index_map$mset, .set_names(
    as.list(seq_len(n) - 1L),
    node_names
  ))

  state <- .cg_state(
    nodes = nodes_tbl,
    edges = edges_tbl,
    ptr = ptr,
    built = TRUE,
    simple = is_simple_ptr(ptr),
    class = graph_class_ptr(ptr),
    name_index_map = name_index_map
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
#' @param ptr A pointer to the underlying Rust graph structure
#' (or `NULL` if not built).
#' @param built Logical; whether the graph has been built.
#' @param simple Logical; whether the graph is simple
#' (no parallel edges or self-loops).
#' @param class Character; one of `"UNKNOWN"`, `"DAG"`, or `"PDAG"`.
#' @param name_index_map A `fastmap` mapping node names to their zero indexed
#' indices.
#'
#' @returns An environment containing the graph state.
#'
#' @keywords internal
.cg_state <- function(nodes, edges, ptr, built, simple, class,
                      name_index_map, index_name_map) {
  e <- new.env(parent = emptyenv())
  e$nodes <- nodes
  e$edges <- edges
  e$ptr <- ptr
  e$built <- isTRUE(built)
  e$simple <- isTRUE(simple)
  e$class <- class
  e$name_index_map <- name_index_map
  e
}

#' @title Internal: Freeze the state environment of a `caugi`
#'
#' @description Internal functions to freeze and unfreeze the state environment
#' of a `caugi`, preventing further modifications. These functions are not
#' intended to be used directly by users.
#'
#' @param e The state environment to freeze/unfreeze.
#'
#' @returns The frozen/unfrozen environment.
#'
#' @name freeze_state
#'
#' @keywords internal
.freeze_state <- function(e) {
  for (nm in ls(envir = e, all.names = TRUE)) lockBinding(nm, e)
  lockEnvironment(e, bindings = TRUE)
  e
}

#' @name freeze_state
#'
#' @keywords internal
.unfreeze_state <- function(e) {
  for (nm in ls(envir = e, all.names = TRUE)) unlockBinding(nm, e)
  e
}
