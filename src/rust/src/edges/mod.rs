// SPDX-License-Identifier: MIT
//! Edge specification and registry with endpoint Marks.

use std::{collections::HashMap, error::Error, fmt, result::Result, str::FromStr};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Mark {
    Arrow,
    Tail,
    Circle,
    Other,
}

impl FromStr for Mark {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "arrow" => Ok(Mark::Arrow),
            "tail" => Ok(Mark::Tail),
            "circle" => Ok(Mark::Circle),
            "other" => Ok(Mark::Other),
            _ => Err(format!("Unknown mark '{}'", s)),
        }
    }
}

impl fmt::Display for Mark {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            Mark::Arrow => "arrow",
            Mark::Tail => "tail",
            Mark::Circle => "circle",
            Mark::Other => "other",
        };
        write!(f, "{}", s)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EdgeClass {
    Directed,
    Undirected,
    Bidirected,
    PartiallyDirected,
    PartiallyUndirected,
    Partial, // for o-o
}

impl FromStr for EdgeClass {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "directed" => Ok(EdgeClass::Directed),
            "undirected" => Ok(EdgeClass::Undirected),
            "bidirected" => Ok(EdgeClass::Bidirected),
            "partial" => Ok(EdgeClass::Partial),
            "partially_directed" => Ok(EdgeClass::PartiallyDirected),
            "partially_undirected" => Ok(EdgeClass::PartiallyUndirected),
            _ => Err(format!("Unknown class '{}'", s)),
        }
    }
}

impl fmt::Display for EdgeClass {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            EdgeClass::Directed => "directed",
            EdgeClass::Undirected => "undirected",
            EdgeClass::Bidirected => "bidirected",
            EdgeClass::Partial => "partial",
            EdgeClass::PartiallyDirected => "partially_directed",
            EdgeClass::PartiallyUndirected => "partially_undirected",
        };
        write!(f, "{}", s)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EdgeSpec {
    pub glyph: String,
    pub tail: Mark,
    pub head: Mark,
    pub symmetric: bool,
    pub class: EdgeClass,
}

impl EdgeSpec {
    pub fn glyph<S: Into<String>>(mut self, g: S) -> Self {
        self.glyph = g.into();
        self
    }
}

#[derive(Debug)]
#[non_exhaustive]
pub enum RegistryError {
    Sealed,
    TooManyTypes,
    Conflict { glyph: String },
    UnknownGlyph(String),
    InvalidCode(u8),
}

impl fmt::Display for RegistryError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        use RegistryError::*;
        match self {
            Sealed => write!(f, "Edge registry is sealed"),
            TooManyTypes => write!(f, "Edge registry full (max 256)"),
            Conflict { glyph } => write!(
                f,
                "The glyph '{}' already registered with different semantics",
                glyph
            ),
            UnknownGlyph(g) => write!(f, "Unknown glyph '{}'", g),
            InvalidCode(c) => write!(f, "Invalid edge code {}", c),
        }
    }
}

impl Error for RegistryError {}

#[derive(Debug, Clone, Default)]
pub struct EdgeRegistry {
    glyph_to_code: HashMap<String, u8>,
    code_to_spec: Vec<EdgeSpec>, // index = code
    sealed: bool,
}

impl EdgeRegistry {
    const MAX_TYPES: usize = 256;

    pub fn new() -> Self {
        Self {
            glyph_to_code: HashMap::new(),
            code_to_spec: Vec::new(),
            sealed: false,
        }
    }
    pub fn is_sealed(&self) -> bool {
        self.sealed
    }
    pub fn is_empty(&self) -> bool {
        self.code_to_spec.is_empty()
    }
    pub fn seal(&mut self) {
        self.sealed = true;
    }

    pub fn len(&self) -> usize {
        self.code_to_spec.len()
    }

    pub fn register(&mut self, spec: EdgeSpec) -> Result<u8, RegistryError> {
        if self.sealed {
            return Err(RegistryError::Sealed);
        }

        if let Some(&code) = self.glyph_to_code.get(&spec.glyph) {
            let existing = &self.code_to_spec[code as usize];
            return if existing == &spec {
                Ok(code)
            } else {
                Err(RegistryError::Conflict {
                    glyph: spec.glyph.clone(),
                })
            };
        }

        if self.code_to_spec.len() >= Self::MAX_TYPES {
            return Err(RegistryError::TooManyTypes);
        }

        let code = self.code_to_spec.len() as u8;
        self.glyph_to_code.insert(spec.glyph.clone(), code);
        self.code_to_spec.push(spec);
        Ok(code)
    }

    pub fn code_of(&self, glyph: &str) -> Result<u8, RegistryError> {
        match self.glyph_to_code.get(glyph) {
            Some(&code) => Ok(code),
            None => Err(RegistryError::UnknownGlyph(glyph.to_string())),
        }
    }

    pub fn spec_of_code(&self, code: u8) -> Result<&EdgeSpec, RegistryError> {
        match self.code_to_spec.get(code as usize) {
            Some(spec) => Ok(spec),
            None => Err(RegistryError::InvalidCode(code)),
        }
    }

    /// Convenience: fetch spec directly by glyph.
    pub fn spec_of(&self, glyph: &str) -> Result<&EdgeSpec, RegistryError> {
        let code = self.code_of(glyph)?;
        self.spec_of_code(code)
    }

    /// Register built-ins. Idempotent if called multiple times.
    pub fn register_builtins(&mut self) -> Result<(), RegistryError> {
        use EdgeClass as C;
        use Mark as M;

        let mut add = |glyph: &str,
                       tail: M,
                       head: M,
                       symmetric: bool,
                       class: C|
         -> Result<(), RegistryError> {
            self.register(EdgeSpec {
                glyph: glyph.to_string(),
                tail,
                head,
                symmetric,
                class,
            })
            .map(|_| ())
        };

        // Built-in mappings
        add("-->", M::Tail, M::Arrow, false, C::Directed)?;
        add("---", M::Tail, M::Tail, true, C::Undirected)?;
        add("<->", M::Arrow, M::Arrow, true, C::Bidirected)?;
        add("o-o", M::Circle, M::Circle, true, C::Partial)?;
        add("--o", M::Tail, M::Circle, false, C::PartiallyUndirected)?;
        add("o->", M::Circle, M::Arrow, false, C::PartiallyDirected)?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn built_reg() -> EdgeRegistry {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        r
    }

    #[test]
    fn builtins_present_and_len() {
        let r = built_reg();
        assert_eq!(r.len(), 6);
        for g in ["-->", "---", "<->", "o-o", "--o", "o->"] {
            assert!(r.code_of(g).is_ok(), "missing builtin {}", g);
        }
    }

    #[test]
    fn register_new_and_fetch_spec() {
        let mut r = built_reg();
        let before = r.len();
        let spec = EdgeSpec {
            glyph: "--<".into(),
            tail: Mark::Tail,
            head: Mark::Arrow,
            symmetric: false,
            class: EdgeClass::Directed,
        };
        let code = r.register(spec.clone()).unwrap();
        assert_eq!(r.len(), before + 1);
        let got = r.spec_of_code(code).unwrap();
        assert_eq!(got, &spec);
    }

    #[test]
    fn idempotent_same_spec_returns_same_code() {
        let mut r = built_reg();
        let spec = EdgeSpec {
            glyph: "o-O".into(),
            tail: Mark::Circle,
            head: Mark::Other,
            symmetric: false,
            class: EdgeClass::Partial,
        };
        let c1 = r.register(spec.clone()).unwrap();
        let c2 = r.register(spec).unwrap();
        assert_eq!(c1, c2);
    }

    #[test]
    fn conflict_and_seal_behavior() {
        let mut r = built_reg();
        // conflict: redefine existing glyph with different semantics
        let bad = EdgeSpec {
            glyph: "-->".into(),
            tail: Mark::Tail,
            head: Mark::Tail,
            symmetric: true,
            class: EdgeClass::Undirected,
        };
        assert!(matches!(
            r.register(bad),
            Err(RegistryError::Conflict { .. })
        ));

        // seal prevents any further registrations
        r.seal();
        let new = EdgeSpec {
            glyph: "x".into(),
            tail: Mark::Other,
            head: Mark::Other,
            symmetric: true,
            class: EdgeClass::Undirected,
        };
        assert!(matches!(r.register(new), Err(RegistryError::Sealed)));
    }

    #[test]
    fn unknown_glyph_and_invalid_code_errors() {
        let r = built_reg();
        assert!(matches!(
            r.code_of("does-not-exist"),
            Err(RegistryError::UnknownGlyph(_))
        ));
        assert!(matches!(
            r.spec_of_code(250),
            Err(RegistryError::InvalidCode(_))
        ));
    }
    #[test]
    fn parse_mark_and_edgeclass_fromstr() {
        use std::str::FromStr;
        assert_eq!(Mark::from_str("arrow").unwrap(), Mark::Arrow);
        assert_eq!(Mark::from_str("tail").unwrap(), Mark::Tail);
        assert_eq!(Mark::from_str("circle").unwrap(), Mark::Circle);
        assert_eq!(Mark::from_str("other").unwrap(), Mark::Other);
        assert!(Mark::from_str("nope").is_err());

        assert_eq!(
            EdgeClass::from_str("directed").unwrap(),
            EdgeClass::Directed
        );
        assert_eq!(
            EdgeClass::from_str("undirected").unwrap(),
            EdgeClass::Undirected
        );
        assert_eq!(
            EdgeClass::from_str("bidirected").unwrap(),
            EdgeClass::Bidirected
        );
        assert_eq!(EdgeClass::from_str("partial").unwrap(), EdgeClass::Partial);
        assert_eq!(
            EdgeClass::from_str("partially_directed").unwrap(),
            EdgeClass::PartiallyDirected
        );
        assert_eq!(
            EdgeClass::from_str("partially_undirected").unwrap(),
            EdgeClass::PartiallyUndirected
        );
        assert!(EdgeClass::from_str("???").is_err());
    }

    #[test]
    fn spec_glyph_setter_and_convenience_lookups() {
        let mut r = built_reg();
        // builder-style glyph()
        let s = EdgeSpec {
            glyph: "".into(),
            tail: Mark::Tail,
            head: Mark::Arrow,
            symmetric: false,
            class: EdgeClass::Directed,
        }
        .glyph("x->");
        let c = r.register(s.clone()).unwrap();
        assert_eq!(r.spec_of("x->").unwrap(), &s);
        assert_eq!(r.spec_of_code(c).unwrap().glyph, "x->");
    }

    #[test]
    fn idempotent_register_builtins_and_basic_introspection() {
        let mut r = EdgeRegistry::new();
        assert!(r.is_empty());
        assert!(!r.is_sealed());
        r.register_builtins().unwrap();
        let len1 = r.len();
        r.register_builtins().unwrap(); // idempotent
        assert_eq!(r.len(), len1);
        assert!(!r.is_empty());
    }

    #[test]
    fn display_errors_text() {
        let e1 = RegistryError::UnknownGlyph("xx".into());
        let e2 = RegistryError::InvalidCode(255);
        let e3 = RegistryError::TooManyTypes;
        let e4 = RegistryError::Sealed;
        assert!(format!("{}", e1).contains("Unknown glyph 'xx'"));
        assert!(format!("{}", e2).contains("Invalid edge code 255"));
        assert!(format!("{}", e3).contains("Edge registry full"));
        assert!(format!("{}", e4).contains("sealed"));
    }

    #[test]
    fn too_many_types_limit_enforced() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        // Fill up to MAX_TYPES
        let start = r.len();
        for i in start..EdgeRegistry::MAX_TYPES {
            let g = format!("g{}", i);
            let spec = EdgeSpec {
                glyph: g,
                tail: Mark::Other,
                head: Mark::Other,
                symmetric: true,
                class: EdgeClass::Undirected,
            };
            r.register(spec).unwrap();
        }
        assert_eq!(r.len(), EdgeRegistry::MAX_TYPES);
        // Next should fail
        let overflow = EdgeSpec {
            glyph: "overflow".into(),
            tail: Mark::Other,
            head: Mark::Other,
            symmetric: true,
            class: EdgeClass::Undirected,
        };
        assert!(matches!(
            r.register(overflow),
            Err(RegistryError::TooManyTypes)
        ));
    }

    #[test]
    fn seal_and_is_sealed_reported() {
        let mut r = built_reg();
        assert!(!r.is_sealed());
        r.seal();
        assert!(r.is_sealed());
    }

    #[test]
    fn conflict_display_includes_glyph_and_text() {
        let mut r = built_reg();
        let err = r
            .register(EdgeSpec {
                glyph: "-->".into(), // existing glyph with different semantics
                tail: Mark::Tail,
                head: Mark::Tail,
                symmetric: true,
                class: EdgeClass::Undirected,
            })
            .unwrap_err();
        let msg = err.to_string();
        assert!(msg.contains("already registered with different semantics"));
        assert!(msg.contains("'-->'"));
    }

    #[test]
    fn display_for_mark_and_edgeclass() {
        assert_eq!(format!("{}", Mark::Arrow), "arrow");
        assert_eq!(format!("{}", Mark::Tail), "tail");
        assert_eq!(format!("{}", Mark::Circle), "circle");
        assert_eq!(format!("{}", Mark::Other), "other");

        assert_eq!(format!("{}", EdgeClass::Directed), "directed");
        assert_eq!(format!("{}", EdgeClass::Undirected), "undirected");
        assert_eq!(format!("{}", EdgeClass::Bidirected), "bidirected");
        assert_eq!(format!("{}", EdgeClass::Partial), "partial");
        assert_eq!(
            format!("{}", EdgeClass::PartiallyDirected),
            "partially_directed"
        );
        assert_eq!(
            format!("{}", EdgeClass::PartiallyUndirected),
            "partially_undirected"
        );
    }
}
