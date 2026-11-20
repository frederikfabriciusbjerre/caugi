// SPDX-License-Identifier: MIT
//! Marker traits for graph classes.
//!
//! Marker traits (`Acyclic`, `MeekClosed`, `NoUndirected`, `NoBidirected`,
//! `OnlyDirected`) encode invariants that have already been validated at
//! construction time. Algorithms generic over these traits can skip the
//! corresponding runtime probe.

pub mod markers;

pub use markers::{Acyclic, MeekClosed, NoBidirected, NoUndirected, OnlyDirected};
