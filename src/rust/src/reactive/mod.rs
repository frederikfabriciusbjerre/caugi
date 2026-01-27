// SPDX-License-Identifier: MIT
//! Internal reactive framework for declarative graph computation.
//!
//! This module provides a lightweight reactive system with:
//! - `Invalidator`: Batch invalidation support with dependency tracking
//! - `Variable<T>`: Mutable values that trigger invalidation on change
//! - `Declaration<T>`: Computed values with lazy evaluation and caching
//!
//! Note: Signals are intentionally omitted from this implementation.

use std::collections::HashSet;

/// Batch invalidation tracker.
///
/// Tracks which items have been invalidated and supports manual completion
/// for batch operations that should only trigger recomputation once.
#[derive(Debug, Clone)]
pub(crate) struct Invalidator {
    invalidated: HashSet<usize>,
    completed: HashSet<usize>,
    manual_complete: bool,
}

impl Invalidator {
    /// Create a new invalidator.
    ///
    /// If `manual_complete` is true, `allow_completion` must be called
    /// before invalidation is considered complete.
    pub fn new(manual_complete: bool) -> Self {
        Self {
            invalidated: HashSet::new(),
            completed: HashSet::new(),
            manual_complete,
        }
    }

    /// Create an invalidator that completes immediately (no manual step needed).
    pub fn immediate() -> Self {
        Self::new(false)
    }

    /// Create an invalidator that requires manual completion.
    pub fn manual() -> Self {
        Self::new(true)
    }

    /// Invalidate an item and all its dependents recursively.
    ///
    /// The `get_dependents` function should return the list of items that
    /// depend on the given item (downstream dependencies).
    pub fn invalidate<F>(&mut self, id: usize, get_dependents: F)
    where
        F: Fn(usize) -> Vec<usize>,
    {
        self.invalidate_inner(id, &get_dependents);
    }

    fn invalidate_inner<F>(&mut self, id: usize, get_dependents: &F)
    where
        F: Fn(usize) -> Vec<usize>,
    {
        if self.invalidated.contains(&id) {
            return;
        }
        self.invalidated.insert(id);
        for dep in get_dependents(id) {
            self.invalidate_inner(dep, get_dependents);
        }
        self.completed.insert(id);
    }

    /// Allow completion of the invalidation batch.
    /// This is a no-op if the invalidator was created with `manual_complete = false`.
    pub fn allow_completion(&mut self) {
        self.manual_complete = false;
    }

    /// Check if invalidation is complete.
    pub fn is_complete(&self) -> bool {
        !self.manual_complete
    }

    /// Get the set of invalidated item IDs.
    pub fn invalidated_items(&self) -> &HashSet<usize> {
        &self.invalidated
    }

    /// Clear all tracked invalidations.
    pub fn clear(&mut self) {
        self.invalidated.clear();
        self.completed.clear();
    }
}

/// Trait for items that can be invalidated.
pub(crate) trait Invalidatable {
    /// Mark this item as invalid.
    fn invalidate(&mut self);

    /// Check if this item is currently valid.
    fn is_valid(&self) -> bool;
}

/// A mutable variable that tracks validity.
///
/// When the value changes, dependents should be invalidated.
#[derive(Debug, Clone)]
pub(crate) struct Variable<T> {
    value: T,
    valid: bool,
}

impl<T> Variable<T> {
    /// Create a new variable with the given initial value.
    pub fn new(value: T) -> Self {
        Self { value, valid: true }
    }

    /// Get a reference to the current value.
    pub fn get(&self) -> &T {
        &self.value
    }

    /// Set the value and mark as valid.
    /// Returns true if the value was set (for change detection, use `set_if_changed`).
    pub fn set(&mut self, value: T) {
        self.value = value;
        self.valid = true;
    }

    /// Get a mutable reference to the current value.
    pub fn get_mut(&mut self) -> &mut T {
        &mut self.value
    }

    /// Take ownership of the value, leaving a default in its place.
    pub fn take(&mut self) -> T
    where
        T: Default,
    {
        self.valid = false;
        std::mem::take(&mut self.value)
    }
}

impl<T: PartialEq> Variable<T> {
    /// Set the value only if it differs from the current value.
    /// Returns true if the value was changed.
    pub fn set_if_changed(&mut self, value: T) -> bool {
        if self.value != value {
            self.value = value;
            self.valid = true;
            true
        } else {
            false
        }
    }
}

impl<T> Invalidatable for Variable<T> {
    fn invalidate(&mut self) {
        self.valid = false;
    }

    fn is_valid(&self) -> bool {
        self.valid
    }
}

/// A computed declaration with lazy evaluation and caching.
///
/// The cached value is recomputed only when accessed after invalidation.
#[derive(Debug, Clone)]
pub(crate) struct Declaration<T> {
    /// Cached computed value (None if never computed or invalidated).
    cached: Option<T>,
    /// Whether the cached value is currently valid.
    valid: bool,
}

impl<T> Declaration<T> {
    /// Create a new declaration without checkpointing.
    pub fn new() -> Self {
        Self {
            cached: None,
            valid: false,
        }
    }

    /// Get the cached value if valid.
    pub fn get(&self) -> Option<&T> {
        if self.valid {
            self.cached.as_ref()
        } else {
            None
        }
    }

    /// Set the computed value and mark as valid.
    pub fn set(&mut self, value: T) {
        self.cached = Some(value);
        self.valid = true;
    }

    /// Set the computed value without cloning (consumes value).
    pub fn set_owned(&mut self, value: T) {
        self.cached = Some(value);
        self.valid = true;
    }
}

impl<T> Default for Declaration<T> {
    fn default() -> Self {
        Self::new()
    }
}

impl<T> Invalidatable for Declaration<T> {
    fn invalidate(&mut self) {
        self.valid = false;
        self.cached = None;
    }

    fn is_valid(&self) -> bool {
        self.valid
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn invalidator_immediate_completion() {
        let inv = Invalidator::immediate();
        assert!(inv.is_complete());
    }

    #[test]
    fn invalidator_manual_completion() {
        let mut inv = Invalidator::manual();
        assert!(!inv.is_complete());
        inv.allow_completion();
        assert!(inv.is_complete());
    }

    #[test]
    fn invalidator_tracks_invalidated_items() {
        let mut inv = Invalidator::immediate();
        inv.invalidate(1, |_| vec![]);
        inv.invalidate(2, |_| vec![]);

        let items = inv.invalidated_items();
        assert!(items.contains(&1));
        assert!(items.contains(&2));
        assert_eq!(items.len(), 2);
    }

    #[test]
    fn invalidator_cascades_to_dependents() {
        let mut inv = Invalidator::immediate();

        // Dependency graph: 1 -> [2, 3], 2 -> [4]
        let get_deps = |id: usize| -> Vec<usize> {
            match id {
                1 => vec![2, 3],
                2 => vec![4],
                _ => vec![],
            }
        };

        inv.invalidate(1, get_deps);

        let items = inv.invalidated_items();
        assert!(items.contains(&1));
        assert!(items.contains(&2));
        assert!(items.contains(&3));
        assert!(items.contains(&4));
        assert_eq!(items.len(), 4);
    }

    #[test]
    fn variable_set_and_get() {
        let mut var = Variable::new(42);
        assert_eq!(*var.get(), 42);
        assert!(var.is_valid());

        var.set(100);
        assert_eq!(*var.get(), 100);
    }

    #[test]
    fn variable_set_if_changed() {
        let mut var = Variable::new(42);

        // No change
        assert!(!var.set_if_changed(42));

        // Change
        assert!(var.set_if_changed(100));
        assert_eq!(*var.get(), 100);
    }

    #[test]
    fn variable_invalidation() {
        let mut var = Variable::new(42);
        assert!(var.is_valid());

        var.invalidate();
        assert!(!var.is_valid());
    }

    #[test]
    fn declaration_lazy_evaluation() {
        let mut decl: Declaration<i32> = Declaration::new();

        // Initially no cached value
        assert!(decl.get().is_none());
        assert!(!decl.is_valid());

        // Set value
        decl.set(42);
        assert!(decl.is_valid());
        assert_eq!(decl.get(), Some(&42));

        // Invalidate
        decl.invalidate();
        assert!(!decl.is_valid());
        assert!(decl.get().is_none());
    }

}
