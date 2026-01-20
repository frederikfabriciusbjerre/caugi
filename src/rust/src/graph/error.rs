// SPDX-License-Identifier: MIT
//! Error types for graph operations.

// ── ADMG Errors ───────────────────────────────────────────────────────────────

/// Errors that can occur when constructing or validating an ADMG.
#[derive(Debug, Clone)]
pub enum AdmgError {
    /// The directed part of the graph contains a cycle.
    DirectedCycle,
    /// An invalid edge type was found (only directed and bidirected are allowed).
    InvalidEdgeType { found: String },
    /// A node index is out of bounds.
    InvalidNodeIndex { index: u32, max: u32 },
}

impl std::fmt::Display for AdmgError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::DirectedCycle => write!(f, "ADMG contains a directed cycle"),
            Self::InvalidEdgeType { found } => write!(
                f,
                "ADMG can only contain directed and bidirected edges, found: {}",
                found
            ),
            Self::InvalidNodeIndex { index, max } => {
                write!(f, "Node index {} out of bounds (max: {})", index, max)
            }
        }
    }
}

impl std::error::Error for AdmgError {}

// ── DAG Errors ────────────────────────────────────────────────────────────────

/// Errors that can occur when constructing or validating a DAG.
#[derive(Debug, Clone)]
pub enum DagError {
    /// The graph contains a directed cycle.
    DirectedCycle,
    /// An invalid edge type was found (only directed edges are allowed).
    InvalidEdgeType { found: String },
}

impl std::fmt::Display for DagError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::DirectedCycle => write!(f, "DAG contains a directed cycle"),
            Self::InvalidEdgeType { found } => {
                write!(f, "DAG can only contain directed edges, found: {}", found)
            }
        }
    }
}

impl std::error::Error for DagError {}

// ── PDAG Errors ───────────────────────────────────────────────────────────────

/// Errors that can occur when constructing or validating a PDAG.
#[derive(Debug, Clone)]
pub enum PdagError {
    /// The directed part of the graph contains a cycle.
    DirectedCycle,
    /// An invalid edge type was found (only directed and undirected are allowed).
    InvalidEdgeType { found: String },
}

impl std::fmt::Display for PdagError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::DirectedCycle => write!(f, "PDAG contains a directed cycle"),
            Self::InvalidEdgeType { found } => write!(
                f,
                "PDAG can only contain directed and undirected edges, found: {}",
                found
            ),
        }
    }
}

impl std::error::Error for PdagError {}

// ── UG Errors ─────────────────────────────────────────────────────────────────

/// Errors that can occur when constructing or validating an UG.
#[derive(Debug, Clone)]
pub enum UgError {
    /// An invalid edge type was found (only undirected edges are allowed).
    InvalidEdgeType { found: String },
}

impl std::fmt::Display for UgError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::InvalidEdgeType { found } => {
                write!(f, "UG can only contain undirected edges, found: {}", found)
            }
        }
    }
}

impl std::error::Error for UgError {}

// ── AG Errors ────────────────────────────────────────────────────────────────

/// Errors that can occur when constructing or validating an Ancestral Graph.
#[derive(Debug, Clone)]
pub enum AgError {
    /// The directed part of the graph contains a cycle.
    DirectedCycle,
    /// An invalid edge type was found (only directed, bidirected, and undirected are allowed).
    InvalidEdgeType { found: String },
    /// Anterior constraint violated: a node with an arrowhead is an anterior of the source.
    AnteriorConstraintViolation { source: u32, target: u32 },
    /// Undirected constraint violated: a node has both undirected and arrowhead edges.
    UndirectedConstraintViolation { node: u32 },
}

impl std::fmt::Display for AgError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::DirectedCycle => write!(f, "Ancestral graph contains a directed cycle"),
            Self::InvalidEdgeType { found } => write!(
                f,
                "Ancestral graph can only contain directed, bidirected, and undirected edges, found: {}",
                found
            ),
            Self::AnteriorConstraintViolation { source, target } => write!(
                f,
                "Anterior constraint violated: node {} has arrowhead from {} but is an anterior of {}",
                target, source, source
            ),
            Self::UndirectedConstraintViolation { node } => write!(
                f,
                "Undirected constraint violated: node {} has both undirected and arrowhead edges",
                node
            ),
        }
    }
}

impl std::error::Error for AgError {}

// ── Builder Errors ────────────────────────────────────────────────────────────

/// Errors that can occur when building a graph.
#[derive(Debug, Clone)]
pub enum BuilderError {
    /// A node index is out of bounds.
    NodeOutOfRange { node: u32, max: u32 },
    /// Self-loops are not allowed in simple graphs.
    SelfLoop { node: u32 },
    /// Parallel edges are not allowed in simple graphs.
    ParallelEdge { from: u32, to: u32 },
    /// Duplicate edge detected.
    DuplicateEdge { from: u32, to: u32, edge_type: u8 },
    /// Invalid edge code.
    InvalidEdgeCode { code: u8 },
    /// CSR array length mismatch.
    CsrLengthMismatch,
}

impl std::fmt::Display for BuilderError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NodeOutOfRange { node, max } => {
                write!(f, "Node {} out of range (max: {})", node, max)
            }
            Self::SelfLoop { node } => {
                write!(f, "Self-loops not allowed in simple graphs (node {})", node)
            }
            Self::ParallelEdge { from, to } => {
                write!(
                    f,
                    "Parallel edges not allowed in simple graphs ({} -> {})",
                    from, to
                )
            }
            Self::DuplicateEdge {
                from,
                to,
                edge_type,
            } => {
                write!(f, "Duplicate edge {} -> {} (type {})", from, to, edge_type)
            }
            Self::InvalidEdgeCode { code } => write!(f, "Invalid edge code: {}", code),
            Self::CsrLengthMismatch => write!(f, "CSR arrays length mismatch"),
        }
    }
}

impl std::error::Error for BuilderError {}

// ── GraphView Errors ──────────────────────────────────────────────────────────

/// Errors that can occur when using GraphView operations.
#[derive(Debug, Clone)]
pub enum GraphViewError {
    /// Operation not supported for this graph type.
    UnsupportedOperation {
        operation: &'static str,
        graph_type: &'static str,
    },
}

impl std::fmt::Display for GraphViewError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::UnsupportedOperation {
                operation,
                graph_type,
            } => {
                write!(f, "{} is not defined for {}", operation, graph_type)
            }
        }
    }
}

impl std::error::Error for GraphViewError {}

#[cfg(test)]
mod tests {
    use super::*;

    // ── ADMG Error Tests ──────────────────────────────────────────────────────

    #[test]
    fn admg_error_display_directed_cycle() {
        let err = AdmgError::DirectedCycle;
        assert_eq!(err.to_string(), "ADMG contains a directed cycle");
    }

    #[test]
    fn admg_error_display_invalid_edge_type() {
        let err = AdmgError::InvalidEdgeType {
            found: "---".to_string(),
        };
        assert!(err
            .to_string()
            .contains("ADMG can only contain directed and bidirected edges"));
        assert!(err.to_string().contains("---"));
    }

    #[test]
    fn admg_error_display_invalid_node_index() {
        let err = AdmgError::InvalidNodeIndex { index: 10, max: 5 };
        assert!(err.to_string().contains("10"));
        assert!(err.to_string().contains("5"));
    }

    // ── DAG Error Tests ───────────────────────────────────────────────────────

    #[test]
    fn dag_error_display_directed_cycle() {
        let err = DagError::DirectedCycle;
        assert_eq!(err.to_string(), "DAG contains a directed cycle");
    }

    #[test]
    fn dag_error_display_invalid_edge_type() {
        let err = DagError::InvalidEdgeType {
            found: "---".to_string(),
        };
        assert!(err
            .to_string()
            .contains("DAG can only contain directed edges"));
        assert!(err.to_string().contains("---"));
    }

    // ── PDAG Error Tests ──────────────────────────────────────────────────────

    #[test]
    fn pdag_error_display_directed_cycle() {
        let err = PdagError::DirectedCycle;
        assert_eq!(err.to_string(), "PDAG contains a directed cycle");
    }

    #[test]
    fn pdag_error_display_invalid_edge_type() {
        let err = PdagError::InvalidEdgeType {
            found: "<->".to_string(),
        };
        assert!(err
            .to_string()
            .contains("PDAG can only contain directed and undirected edges"));
        assert!(err.to_string().contains("<->"));
    }

    // ── UG Error Tests ────────────────────────────────────────────────────────

    #[test]
    fn ug_error_display_invalid_edge_type() {
        let err = UgError::InvalidEdgeType {
            found: "-->".to_string(),
        };
        assert!(err
            .to_string()
            .contains("UG can only contain undirected edges"));
        assert!(err.to_string().contains("-->"));
    }

    // ── AG Error Tests ────────────────────────────────────────────────────────

    #[test]
    fn ag_error_display_directed_cycle() {
        let err = AgError::DirectedCycle;
        assert_eq!(err.to_string(), "Ancestral graph contains a directed cycle");
    }

    #[test]
    fn ag_error_display_invalid_edge_type() {
        let err = AgError::InvalidEdgeType {
            found: "o->".to_string(),
        };
        assert!(err.to_string().contains(
            "Ancestral graph can only contain directed, bidirected, and undirected edges"
        ));
        assert!(err.to_string().contains("o->"));
    }

    #[test]
    fn ag_error_display_anterior_constraint_violation() {
        let err = AgError::AnteriorConstraintViolation {
            source: 0,
            target: 1,
        };
        assert!(err.to_string().contains("Anterior constraint violated"));
        assert!(err.to_string().contains("node 1"));
    }

    #[test]
    fn ag_error_display_undirected_constraint_violation() {
        let err = AgError::UndirectedConstraintViolation { node: 2 };
        assert!(err.to_string().contains("Undirected constraint violated"));
        assert!(err.to_string().contains("node 2"));
    }

    // ── Builder Error Tests ───────────────────────────────────────────────────

    #[test]
    fn builder_error_display_node_out_of_range() {
        let err = BuilderError::NodeOutOfRange { node: 10, max: 5 };
        assert!(err.to_string().contains("10"));
        assert!(err.to_string().contains("5"));
    }

    #[test]
    fn builder_error_display_self_loop() {
        let err = BuilderError::SelfLoop { node: 3 };
        assert!(err.to_string().contains("Self-loops not allowed"));
        assert!(err.to_string().contains("3"));
    }

    #[test]
    fn builder_error_display_parallel_edge() {
        let err = BuilderError::ParallelEdge { from: 1, to: 2 };
        assert!(err.to_string().contains("Parallel edges not allowed"));
        assert!(err.to_string().contains("1"));
        assert!(err.to_string().contains("2"));
    }

    #[test]
    fn builder_error_display_duplicate_edge() {
        let err = BuilderError::DuplicateEdge {
            from: 1,
            to: 2,
            edge_type: 0,
        };
        assert!(err.to_string().contains("Duplicate edge"));
    }

    #[test]
    fn builder_error_display_invalid_edge_code() {
        let err = BuilderError::InvalidEdgeCode { code: 255 };
        assert!(err.to_string().contains("255"));
    }

    // ── GraphView Error Tests ─────────────────────────────────────────────────

    #[test]
    fn graphview_error_display_unsupported_operation() {
        let err = GraphViewError::UnsupportedOperation {
            operation: "parents_of",
            graph_type: "UG",
        };
        assert!(err.to_string().contains("parents_of"));
        assert!(err.to_string().contains("UG"));
    }
}
