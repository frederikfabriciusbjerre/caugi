//! caugi constraints (skeleton).
//!
//! Experimental scaffolding for the constraint system described in
//! `extras/design/constraints-plan.md`. At this stage the module only
//! contains AST type stubs so subsequent commits on the `feat/constraints`
//! branch can fill in parsing, grounding, evaluation, and solver encoding
//! without churning the surrounding layout.
//!
//! The AST is intentionally inert: no extendr exports yet, no public R
//! surface. Lints for unused items are suppressed at the module level so
//! the stub compiles cleanly until the rest of the pipeline lands.

#![allow(dead_code)]

pub mod ast;
pub mod parse;

/// Current AST schema version mirrored on the R side
/// (`caugi_constraints_class@schema_version`).
pub const SCHEMA_VERSION: u32 = 1;
