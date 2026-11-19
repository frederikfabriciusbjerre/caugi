// SPDX-License-Identifier: MIT
//! Background knowledge: what each pair of nodes may be.
//!
//! A statement, a tier and an exogenous node each say which of three things a
//! pair {a, b} may be: no edge, `a --> b` or `b --> a`. That set is
//! [`Allowed`]. Combining knowledge is intersection, and a contradiction is
//! the empty set.

use bitflags::bitflags;

bitflags! {
    /// What the pair {a, b}, a < b, may be.
    #[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
    pub struct Allowed: u8 {
        /// No edge.
        const NONE = 1;
        /// `a --> b`.
        const AB = 2;
        /// `b --> a`.
        const BA = 4;
    }
}

impl Allowed {
    /// Adjacent, either way.
    pub const ADJACENT: Self = Self::AB.union(Self::BA);
    /// Anything but `a --> b`.
    pub const NOT_AB: Self = Self::NONE.union(Self::BA);
    /// Anything but `b --> a`.
    pub const NOT_BA: Self = Self::NONE.union(Self::AB);

    /// The set the statement `a <glyph> b` allows.
    pub fn of_glyph(glyph: &str) -> Option<Self> {
        match glyph {
            "-->" => Some(Self::AB),
            "!-->" => Some(Self::NOT_AB),
            "---" => Some(Self::ADJACENT),
            "!---" => Some(Self::NONE),
            _ => None,
        }
    }

    /// The statement that allows exactly this set: its glyph, and whether it
    /// is written from b to a. `None` for no constraint or a contradiction.
    pub fn glyph(self) -> Option<(&'static str, bool)> {
        match self {
            Self::AB => Some(("-->", false)),
            Self::BA => Some(("-->", true)),
            Self::ADJACENT => Some(("---", false)),
            Self::NONE => Some(("!---", false)),
            Self::NOT_AB => Some(("!-->", false)),
            Self::NOT_BA => Some(("!-->", true)),
            _ => None,
        }
    }

    /// The same set, seen from b.
    pub fn flip(self) -> Self {
        let mut out = self & Self::NONE;
        out.set(Self::AB, self.contains(Self::BA));
        out.set(Self::BA, self.contains(Self::AB));
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn glyphs_round_trip() {
        for g in ["-->", "!-->", "---", "!---"] {
            let m = Allowed::of_glyph(g).unwrap();
            assert_eq!(m.glyph(), Some((g, false)));
            assert_eq!(m.flip().flip(), m);
        }
        assert_eq!(Allowed::AB.flip(), Allowed::BA);
        assert_eq!(Allowed::NOT_AB.flip().glyph(), Some(("!-->", true)));
        assert_eq!(Allowed::all().glyph(), None);
        assert_eq!(Allowed::empty().glyph(), None);
        assert_eq!(Allowed::of_glyph("<->"), None);
    }
}
