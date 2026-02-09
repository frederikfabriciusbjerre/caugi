# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── Operations ──────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Moralize a DAG
#'
#' @description
#' Moralizing a DAG involves connecting all parents of each node and then
#' converting all directed edges into undirected edges.
#'
#' @details
#' This changes the graph from a Directed Acyclic Graph (DAG) to an
#' Undirected Graph (UG), also known as a Markov Graph.
#'
#'
#' @param cg A `caugi` object (DAG).
#'
#' @returns A `caugi` object representing the moralized graph (UG).
#'
#' @examples
#' cg <- caugi(A %-->% C, B %-->% C, class = "DAG")
#' moralize(cg) # A -- B, A -- C, B -- C
#'
#' @family operations
#' @concept operations
#'
#' @export
moralize <- function(cg) {
  is_caugi(cg, throw_error = TRUE)
  if (cg@graph_class != "DAG") {
    stop("moralize() can only be applied to DAGs.", call. = FALSE)
  }

  moralized_session <- rs_moralize(cg@session)
  .session_to_caugi(moralized_session, node_names = cg@nodes$name)
}

#' @title Get the skeleton of a graph
#'
#' @description
#' The skeleton of a graph is obtained by replacing all directed edges with
#' undirected edges.
#'
#' @details
#' This changes the graph from any class to an Undirected Graph (UG), also known
#' as a Markov Graph.
#'
#' @param cg A `caugi` object. Either a DAG or PDAG.
#'
#' @returns A `caugi` object representing the skeleton of the graph (UG).
#'
#' @examples
#' cg <- caugi(A %-->% B, class = "DAG")
#' skeleton(cg) # A --- B
#'
#' @family operations
#' @concept operations
#'
#' @export
skeleton <- function(cg) {
  is_caugi(cg, throw_error = TRUE)
  skeleton_session <- rs_skeleton(cg@session)
  .session_to_caugi(skeleton_session, node_names = cg@nodes$name)
}

#' @title Project latent variables from a DAG to an ADMG
#'
#' @description
#' Projects out latent (unobserved) variables from a DAG to produce an
#' Acyclic Directed Mixed Graph (ADMG) over the observed variables.
#'
#' @param cg A `caugi` object of class `"DAG"`.
#' @param latents Character vector of latent variable names to project out.
#'
#' @returns A `caugi` object of class `"ADMG"` containing only the observed
#'   variables.
#'
#' @examples
#' # DAG with latent confounder U
#' dag <- caugi(
#'   U %-->% X,
#'   U %-->% Y,
#'   X %-->% Y,
#'   class = "DAG"
#' )
#'
#' # Project out the latent variable
#' admg <- latent_project(dag, latents = "U")
#' # Result: X -> Y, X <-> Y (children of U become bidirected-connected)
#' edges(admg)
#'
#' # DAG with directed path through latent
#' dag2 <- caugi(
#'   X %-->% L,
#'   L %-->% Y,
#'   class = "DAG"
#' )
#'
#' # Project out the latent variable
#' admg2 <- latent_project(dag2, latents = "L")
#' # Result: X -> Y (directed path X -> L -> Y becomes X -> Y)
#' edges(admg2)
#'
#' @family operations
#' @concept operations
#'
#' @export
latent_project <- function(cg, latents) {
  is_caugi(cg, throw_error = TRUE)

  if (!is_dag(cg)) {
    stop("latent_project() can only be applied to DAGs.", call. = FALSE)
  }

  if (!is.character(latents)) {
    stop("`latents` must be a character vector of node names.", call. = FALSE)
  }

  node_names <- cg@nodes$name

  # Validate latent names exist
  missing_latents <- setdiff(latents, node_names)
  if (length(missing_latents) > 0L) {
    stop(
      paste0(
        "Unknown latent node(s): ",
        paste(missing_latents, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  # Get 0-based indices for latent nodes
  latent_indices <- rs_indices_of(cg@session, latents)

  # Get observed node names (preserving order)
  is_latent <- node_names %in% latents
  observed_names <- node_names[!is_latent]

  # Call Rust function
  projected_session <- rs_latent_project(cg@session, latent_indices)

  # Convert result back to caugi
  .session_to_caugi(projected_session, node_names = observed_names)
}

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── Mutate caugi class ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Mutate `caugi` class
#'
#' @description
#' Mutate the `caugi` class from one graph class to another, if possible.
#' For example, convert a `DAG` to a `PDAG`, or a fully directed `caugi` of
#' class `UNKNOWN` to a `DAG`. Throws an error if not possible.
#'
#' @details
#' This function returns a copy of the object, and the original remains
#' unchanged.
#'
#' @param cg A `caugi` object.
#' @param class A character string specifying the new class.
#'
#' @returns A `caugi` object of the specified class.
#'
#' @examples
#' cg <- caugi(A %-->% B, class = "UNKNOWN")
#' cg_dag <- mutate_caugi(cg, "DAG")
#'
#' @family operations
#' @concept operations
#'
#' @export
mutate_caugi <- function(cg, class) {
  is_caugi(cg, throw_error = TRUE)
  old_class <- cg@graph_class

  if (old_class == class) {
    return(cg)
  }

  if (is_empty_caugi(cg)) {
    return(caugi(class = class))
  }

  is_mutation_possible <- switch(
    class,
    "DAG" = is_dag(cg),
    "PDAG" = is_pdag(cg),
    "UG" = is_ug(cg),
    "ADMG" = is_admg(cg),
    "AG" = is_ag(cg),
    "UNKNOWN" = TRUE,
    stop(paste0("Unknown target class: ", class))
  )

  if (!is_mutation_possible) {
    stop(
      paste0(
        "Cannot convert caugi of class '",
        old_class,
        "' to '",
        class,
        "'."
      ),
      call. = FALSE
    )
  } else {
    return(caugi(
      nodes = nodes(cg),
      edges_df = edges(cg),
      class = class,
      simple = TRUE
    ))
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Exogenize ──────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @title Exogenize a graph
#'
#' @description
#' Exogenize a graph by removing all ingoing edges to the set of nodes
#' specified (i.e., make the nodes exogenous), as well as joining the
#' parents of the nodes specified to the children of the nodes specified.
#'
#' @param cg A `caugi` object of class `"DAG"`.
#' @param nodes A character vector of node names to exogenize. Must be a subset
#' of the nodes in the graph.
#'
#' @returns A `caugi` object representing the exogenized graph.
#'
#' @examples
#' cg <- caugi(A %-->% B, class = "DAG")
#' exogenize(cg, nodes = "B") # A, B
#'
#' @family operations
#' @concept operations
#'
#' @export
exogenize <- function(cg, nodes) {
  is_caugi(cg, throw_error = TRUE)

  if (cg@graph_class != "DAG") {
    stop(
      "`cg` must be a DAG for `exogenize()`. The input graph is of class ",
      cg@graph_class,
      ".",
      call. = FALSE
    )
  }

  if (!is.character(nodes) || length(nodes) == 0) {
    stop(
      "`nodes` must be a non-empty character vector of node names.",
      call. = FALSE
    )
  }

  all_nodes <- nodes(cg)$name

  for (u in nodes) {
    if (!u %in% all_nodes) {
      stop(paste0("Node ", u, " not in graph."), call. = FALSE)
    }

    pa_u <- parents(cg, u) # NULL or character vector
    ch_u <- children(cg, u) # NULL or character vector

    # Step (i): add edges from every parent of u to every child of u
    if (!is.null(pa_u) && !is.null(ch_u)) {
      # cross-product of pa(u) x ch(u)
      grid <- data.table::CJ(from = pa_u, to = ch_u, unique = TRUE)

      # Avoid self-loops (l -> l)
      grid <- grid[from != to]

      if (nrow(grid) > 0L) {
        cg <- add_edges(
          cg,
          from = grid$from,
          edge = rep("-->", nrow(grid)),
          to = grid$to
        )
      }
    }

    # Step (ii): delete incoming edges into u (l -> u)
    if (!is.null(pa_u) && length(pa_u) > 0L) {
      cg <- remove_edges(
        cg,
        from = pa_u,
        to = rep(u, length(pa_u))
      )
    }
  }

  cg
}


# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────── Marginalize and condition ─────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

#' @importFrom utils combn
NULL

#' @title Marginalize and/or condition on variables in an ancestral graph (AG)
#'
#' @description
#' Marginalize variables out of an AG, and/or condition on variables.
#' Depending on the structure, it could produce a graph with directed,
#' bidirected, and undirected edges.
#'
#' @param cg A `caugi` ancestral graph of class `"AG"`.
#' @param cond_vars Character vector of nodes to condition on.
#' @param marg_vars Character vector of nodes to marginalize over.
#'
#' @returns A `caugi` object of class `"AG"`.
#'
#' @family operations
#' @concept operations
#'
#' @references
#' Definition 4.2.1 in Thomas Richardson. Peter Spirtes. "Ancestral graph
#' Markov models." Ann. Statist. 30 (4) 962 - 1030, August 2002.
#' \doi{10.1214/aos/1031689015}
#'
#' @examples
#' mg <- caugi(
#'   U %-->% X + Y,
#'   A %-->% X,
#'   B %-->% Y,
#'   class = "DAG"
#' )
#'
#' condition_marginalize(mg, marg_vars = "U") # ADMG
#' condition_marginalize(mg, cond_vars = "U") # DAG
#'
#' @export
condition_marginalize <- function(cg, cond_vars = NULL, marg_vars = NULL) {
  is_caugi(cg, throw_error = TRUE)

  if (!is_ag(cg)) {
    stop(
      "`cg` must be an AG for `condition_marginalize()`. ",
      "The input graph is of class ",
      cg@graph_class,
      ".",
      call. = FALSE
    )
  }

  cond_vars_valid <- is.character(cond_vars) && length(cond_vars) > 0L
  marg_vars_valid <- is.character(marg_vars) && length(marg_vars) > 0L

  if (!cond_vars_valid && !marg_vars_valid) {
    stop(
      "Either `cond_vars` or `marg_vars` must be a non-empty character vector ",
      "of node names.",
      call. = FALSE
    )
  }

  if (length(intersect(cond_vars, marg_vars)) > 0L) {
    stop("`cond_vars` and `marg_vars` must be disjoint.", call. = FALSE)
  }

  # Compute remaining nodes after removing conditioned and marginalized vars
  all_node_names <- nodes(cg)$name
  removed_vars <- union(cond_vars, marg_vars)
  remaining_nodes <- setdiff(all_node_names, removed_vars)
  n_remaining <- length(remaining_nodes)

  # Early exit for trivial cases
  if (n_remaining < 2L) {
    return(caugi(nodes = remaining_nodes, class = "AG"))
  }

  # Pre-compute anteriors for all relevant nodes
  nodes_for_anteriors <- union(remaining_nodes, cond_vars)
  anteriors_list <- anteriors(cg, nodes_for_anteriors)
  if (!is.list(anteriors_list)) {
    # Single node case: wrap in named list
    anteriors_list <- .set_names(list(anteriors_list), nodes_for_anteriors)
  }

  # Generate all pairs of remaining nodes
  pair_indices <- combn(n_remaining, 2L)
  n_pairs <- ncol(pair_indices)

  # Pre-allocate edge list
  edge_list <- vector("list", n_pairs)

  for (j in seq_len(n_pairs)) {
    node_a <- remaining_nodes[pair_indices[1L, j]]
    node_b <- remaining_nodes[pair_indices[2L, j]]

    # Check if nodes are adjacent in the original graph
    is_adjacent <- node_a %in% neighbors(cg, nodes = node_b)

    if (!is_adjacent) {
      # Check m-separation for all subsets of (other remaining nodes ∪ cond_vars)
      # Nodes are adjacent if NOT m-separated for ANY conditioning subset
      other_nodes <- setdiff(remaining_nodes, c(node_a, node_b))
      is_adjacent <- .not_m_separated_for_all_subsets(
        cg,
        node_a,
        node_b,
        other_nodes,
        cond_vars
      )
    }

    if (is_adjacent) {
      edge_list[[j]] <- .edge_type_from_anteriors(
        node_a,
        node_b,
        cond_vars,
        anteriors_list
      )
    }
  }

  # Combine edges efficiently using data.table
  non_null <- !vapply(edge_list, is.null, logical(1L))
  edges_df <- data.table::rbindlist(edge_list[non_null])

  caugi(edges_df = edges_df, nodes = remaining_nodes, class = "AG")
}

#' @title
#' Check if nodes are NOT m-separated for all conditioning subsets
#'
#' @description
#' Tests whether two nodes fail to be m-separated for every possible
#' conditioning set formed from `other_nodes` combined with `cond_vars`.
#' If they are never separated, they must be adjacent in the resulting graph.
#'
#' @param cg A `caugi` object.
#' @param node_a First node name.
#' @param node_b Second node name.
#' @param other_nodes Other remaining nodes to form conditioning sets from.
#' @param cond_vars Conditioning variables (always included in conditioning).
#'
#' @returns `TRUE` if nodes are not m-separated for any subset (i.e., adjacent).
#'
#' @keywords internal
.not_m_separated_for_all_subsets <- function(
  cg,
  node_a,
  node_b,
  other_nodes,
  cond_vars
) {
  n_other <- length(other_nodes)

  # Generate all subsets of other_nodes
  subsets <- if (n_other == 0L) {
    list(NULL)
  } else {
    # Build subsets from largest to smallest (often finds separation faster)
    c(
      list(other_nodes),
      if (n_other > 1L) {
        unlist(
          lapply(
            seq_len(n_other - 1L),
            function(k) combn(other_nodes, n_other - k, simplify = FALSE)
          ),
          recursive = FALSE
        )
      },
      list(NULL)
    )
  }

  # Check each conditioning set

  for (subset in subsets) {
    conditioning_set <- c(cond_vars, subset)
    if (length(conditioning_set) == 0L) {
      conditioning_set <- NULL
    }

    if (m_separated(cg, X = node_a, Y = node_b, Z = conditioning_set)) {
      # Found a set that m-separates them: no edge needed
      return(FALSE)
    }
  }

  # Not m-separated for any conditioning set: edge is required

  TRUE
}

#' @title
#' Infer edge type from anterior relationships
#'
#' @description
#' Given two adjacent nodes, infers the edge type (directed, bidirected,
#' or undirected) based on whether each node is in the anterior of the other
#' combined with the conditioning set.
#'
#' @param node_a First node name.
#' @param node_b Second node name.
#' @param cond_vars Conditioning variables.
#' @param anteriors_list Pre-computed list of anteriors for all nodes.
#'
#' @returns A single-row `data.table` with `from`, `edge`, `to` columns.
#'
#' @keywords internal
.edge_type_from_anteriors <- function(
  node_a,
  node_b,
  cond_vars,
  anteriors_list
) {
  # Check if a is in ant(b ∪ S): a is in {b ∪ S} or in anteriors of {b ∪ S}
  nodes_with_b <- c(node_b, cond_vars)
  anteriors_of_b <- unlist(anteriors_list[nodes_with_b], use.names = FALSE)
  a_in_anterior_of_b <- node_a %in% nodes_with_b || node_a %in% anteriors_of_b

  # Check if b is in ant(a ∪ S)

  nodes_with_a <- c(node_a, cond_vars)
  anteriors_of_a <- unlist(anteriors_list[nodes_with_a], use.names = FALSE)
  b_in_anterior_of_a <- node_b %in% nodes_with_a || node_b %in% anteriors_of_a

  if (!a_in_anterior_of_b && !b_in_anterior_of_a) {
    # Neither in anterior of the other: bidirected edge
    data.table::data.table(from = node_a, edge = "<->", to = node_b)
  } else if (a_in_anterior_of_b && b_in_anterior_of_a) {
    # Both in anterior of each other: undirected edge
    data.table::data.table(from = node_a, edge = "---", to = node_b)
  } else if (a_in_anterior_of_b) {
    # a is in anterior of b: a --> b
    data.table::data.table(from = node_a, edge = "-->", to = node_b)
  } else {
    # b is in anterior of a: b --> a
    data.table::data.table(from = node_b, edge = "-->", to = node_a)
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Extend a PDAG to a DAG ──────────────────────
# ──────────────────────────────────────────────────────────────────────────────
#' @title Check if two nodes are connected by an edge
#' @keywords internal
#' @noRd
are_connected <- function(cg, u, v) {
  v %in% neighbors(cg, u, mode = "all")
}

#' @title Extend a PDAG to a DAG using the Dor-Tarsi Algorithm
#' @description
#' Given a Partially Directed Acyclic Graph (PDAG), this function attempts to
#' extend it to a Directed Acyclic Graph (DAG) by orienting the undirected edges
#' while preserving acyclicity and all existing directed edges.
#' The procedure implements the Dor-Tarsi algorithm.
#'
#' If the PDAG cannot be consistently extended to a DAG, the function will raise an error.
#'
#' @param PDAG A `caugi` object of class `"PDAG"`.
#'
#' @returns A `caugi` object of class `"DAG"` representing a DAG extension
#' of the input PDAG.
#'
#' @family operations
#' @concept operations
#'
#' @examples
#' PDAG <- caugi(
#'   A %---% B,
#'   B %---% C,
#'   class = "PDAG"
#' )
#' DAG <- dag_from_pdag(PDAG)
#' edges(DAG)
#'
#' @references
#' Dor, D., & Tarsi, M. (1992). "A simple algorithm to construct a consistent
#' extension of a partially directed acyclic graph",
#' <https://api.semanticscholar.org/CorpusID:122949140>.
#'
#' @export
dag_from_pdag <- function(PDAG) {
  if (PDAG@graph_class != "PDAG") {
    stop("Input must be a caugi PDAG graph")
  }

  output_graph <- PDAG
  temp_graph <- PDAG

  nodes_left <- nodes(temp_graph)$name

  while (length(nodes_left) > 0) {
    found_sink <- FALSE

    for (x in nodes_left) {
      all_edges <- edges(temp_graph)

      # Condition (a): no outgoing directed edges from x
      if (length(children(temp_graph, x)) > 0) {
        next
      }

      # Condition (b): undirected neighbors all connected
      undirected_neighbors <- neighbors(temp_graph, x, mode = "undirected")

      if (length(undirected_neighbors) > 1) {
        neighbor_pairs <- combn(undirected_neighbors, 2, simplify = FALSE)
        if (
          any(
            !sapply(neighbor_pairs, function(p) {
              are_connected(temp_graph, p[1], p[2])
            })
          )
        ) {
          next
        }
      }

      # x is a valid sink
      found_sink <- TRUE
      # Orient all undirected edges toward x in output_graph
      if (length(undirected_neighbors) > 0) {
        # Ensure to also remove A---B if adding B-->A
        output_graph <- remove_edges(
          output_graph,
          from = rep(x, length(undirected_neighbors)),
          to = undirected_neighbors,
          edge = "---"
        )
        output_graph <- remove_edges(
          output_graph,
          from = undirected_neighbors,
          to = rep(x, length(undirected_neighbors)),
          edge = "---"
        )
        output_graph <- set_edges(
          output_graph,
          from = undirected_neighbors,
          to = rep(x, length(undirected_neighbors)),
          edge = "-->"
        )
      }

      # Remove x from working graph
      temp_graph <- do.call(remove_nodes, list(temp_graph, as.name(x)))
      nodes_left <- setdiff(nodes_left, x)
      break
    }

    if (!found_sink) stop("PDAG cannot be extended to a DAG (Dor-Tarsi failed)")
  }

  mutate_caugi(output_graph, "DAG")
}
