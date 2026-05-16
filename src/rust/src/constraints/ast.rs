//! AST types for the constraint system.
//!
//! Mirrors what the R-side classifier produces — see
//! `extras/design/constraints-plan.md` §3 and `R/constraints.R`.
//!
//! Notes:
//!   * `NodeRef` is just a `String`. Quantifier-bound variables are tracked
//!     as plain strings in the `Forall`/`Exists` variants; the grounder
//!     resolves bound vs. named occurrences by name match. We avoid a
//!     separate `Var` variant on `NodeRef` for now — it would force the
//!     parser to know about scopes, with no concrete win at v1.
//!   * `EdgeTypeId` is left out: we keep the glyph string straight from
//!     R until the encoder resolves it through the edge registry.

/// A reference to a node by name.
pub type NodeRef = String;

/// A set of node references — used wherever an atom slot accepts
/// `c(...)` on the R side (e.g. `dsep(c(X1, X2), Y, c(Z1, Z2))`).
pub type NodeSet = Vec<NodeRef>;

/// Atom tier — encoder eligibility.
///
/// * `A` — boolean combinations of edge variables.
/// * `B` — global structural atoms requiring transitive-closure aux
///   variables.
/// * `C` — path-enumeration atoms that don't decompose into a finite
///   boolean combination of edge atoms. Evaluator only.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AtomTier {
    A,
    B,
    C,
}

/// Atomic graph predicate.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Atom {
    /// A directed / undirected / bidirected / partial edge of a specific
    /// type, identified by its glyph (e.g. `"-->"`, `"<->"`, `"o->"`).
    Edge {
        from: NodeRef,
        to: NodeRef,
        etype: String,
    },
    /// Set-membership atom: `elem ∈ query(args)`. The tier is recorded
    /// up front because it's determined by the query, not by the
    /// structural shape.
    Membership {
        elem: NodeRef,
        query: String,
        args: Vec<NodeSet>,
        tier: AtomTier,
    },
    /// Whole-graph acyclicity.
    Acyclic,
    /// Whole-graph (weak) connectedness.
    Connected,
    /// `x` is an observed (non-latent) node.
    Observed { x: NodeRef },
    /// `mid` is a collider on the triple `(a, mid, c)`.
    Collider {
        a: NodeRef,
        mid: NodeRef,
        c: NodeRef,
    },
    /// Unshielded collider: `Collider` plus non-adjacency of the shoulders.
    VStructure {
        a: NodeRef,
        mid: NodeRef,
        c: NodeRef,
    },
    /// d-separation. Tier C — evaluator only.
    Dsep {
        x: NodeSet,
        y: NodeSet,
        given: NodeSet,
    },
}

impl Atom {
    /// Tier classification — used to gate encoder eligibility.
    pub fn tier(&self) -> AtomTier {
        match self {
            Atom::Edge { .. }
            | Atom::Observed { .. }
            | Atom::Collider { .. }
            | Atom::VStructure { .. } => AtomTier::A,
            Atom::Acyclic | Atom::Connected => AtomTier::B,
            Atom::Membership { tier, .. } => *tier,
            Atom::Dsep { .. } => AtomTier::C,
        }
    }
}

/// Cardinality flavour for `at_most` / `at_least` / `exactly`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CardKind {
    AtMost,
    AtLeast,
    Exactly,
}

/// What a cardinality constraint counts.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CardinalitySet {
    /// Classic: count how many of the listed formulas hold.
    Formulas(Vec<Formula>),
    /// Parametric: count the size of a query result (e.g.
    /// `at_most(3, parents(Y))`).
    Query {
        name: String,
        args: Vec<NodeSet>,
        tier: AtomTier,
    },
}

/// Quantifier / parameterised-cardinality scope.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Scope {
    AllNodes,
    OrderedTuples(usize),
    UnorderedSets(usize),
    NamedSet(Vec<String>),
}

/// A constraint formula.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Formula {
    Atom(Atom),
    Not(Box<Formula>),
    And(Vec<Formula>),
    Or(Vec<Formula>),
    Xor(Box<Formula>, Box<Formula>),
    Implies(Box<Formula>, Box<Formula>),
    Forall {
        vars: Vec<String>,
        scope: Scope,
        body: Box<Formula>,
    },
    Exists {
        vars: Vec<String>,
        scope: Scope,
        body: Box<Formula>,
    },
    Cardinality {
        kind: CardKind,
        k: u32,
        set: CardinalitySet,
    },
}
