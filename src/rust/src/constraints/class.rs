//! Graph-class enum for the constraint solver.
//!
//! Each class specifies:
//!   * which edge types its members may contain,
//!   * whether each edge type is symmetric (treated as one variable per
//!     unordered pair) or asymmetric (one variable per ordered pair),
//!   * which structural invariants must hold (acyclicity, mutex, etc.).
//!
//! v2 covers `DAG`, `UG`, `PDAG`, and `ADMG`. Richer classes (`MPDAG`,
//! `AG`, `MAG`, `PAG`) will land in later phases.

use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GraphClass {
    Dag,
    Ug,
    Pdag,
    Admg,
}

impl GraphClass {
    pub fn parse(s: &str) -> Result<Self, String> {
        match s {
            "DAG" => Ok(Self::Dag),
            "UG" => Ok(Self::Ug),
            "PDAG" => Ok(Self::Pdag),
            "ADMG" => Ok(Self::Admg),
            other => Err(format!(
                "Graph class `{}` is not yet supported by the constraint solver. \
                 Supported: DAG, UG, PDAG, ADMG.",
                other
            )),
        }
    }

    /// Edge types this class admits, in canonical order. Each entry is
    /// `(glyph, is_symmetric)` — symmetric edges (`---`, `<->`) share
    /// the same variable across `(u, v)` and `(v, u)`.
    pub fn edge_types(&self) -> &'static [(&'static str, bool)] {
        match self {
            Self::Dag => &[("-->", false)],
            Self::Ug => &[("---", true)],
            Self::Pdag => &[("-->", false), ("---", true)],
            Self::Admg => &[("-->", false), ("<->", true)],
        }
    }

    /// Whether the class requires the directed substructure to be
    /// acyclic. UG has no directed edges, so this is `false` there.
    pub fn requires_directed_acyclicity(&self) -> bool {
        matches!(self, Self::Dag | Self::Pdag | Self::Admg)
    }

    /// The caugi class string used when reconstructing a graph from a
    /// SAT model.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Dag => "DAG",
            Self::Ug => "UG",
            Self::Pdag => "PDAG",
            Self::Admg => "ADMG",
        }
    }
}

impl fmt::Display for GraphClass {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}
