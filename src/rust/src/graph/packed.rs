// SPDX-License-Identifier: MIT
//! Shared utilities for building packed neighborhood storage.
//!
//! This module provides helper types for the common pattern used across
//! typed graph wrappers (Dag, Pdag, Admg, Ag, Ug) where edges are classified
//! into buckets and stored in a packed array.

use std::sync::Arc;

/// Builder for packed bucket storage with a configurable number of buckets.
///
/// The generic parameter `B` specifies the number of buckets per node.
/// For example:
/// - `PackedBucketsBuilder<2>` for DAG (parents, children)
/// - `PackedBucketsBuilder<3>` for PDAG (parents, undirected, children)
/// - `PackedBucketsBuilder<3>` for ADMG (parents, spouses, children)
/// - `PackedBucketsBuilder<4>` for AG (parents, undirected, spouses, children)
/// - `PackedBucketsBuilder<1>` for UG (neighbors)
#[derive(Debug)]
pub struct PackedBucketsBuilder<const B: usize> {
    n: usize,
    deg: Vec<[u32; B]>,
    node_edge_ranges: Vec<usize>,
    neighborhoods: Vec<u32>,
    bucket_bases: Vec<[usize; B]>,
    cursors: Vec<[usize; B]>,
}

impl<const B: usize> PackedBucketsBuilder<B> {
    /// Create a new builder for `n` nodes.
    pub fn new(n: usize) -> Self {
        Self {
            n,
            deg: vec![[0u32; B]; n],
            node_edge_ranges: Vec::with_capacity(n + 1),
            neighborhoods: Vec::new(),
            bucket_bases: vec![[0usize; B]; n],
            cursors: vec![[0usize; B]; n],
        }
    }

    /// Increment the degree for node `i` in bucket `bucket`.
    #[inline]
    pub fn inc_degree(&mut self, i: usize, bucket: usize) {
        debug_assert!(bucket < B, "bucket index out of range");
        debug_assert!(i < self.n, "node index out of range");
        self.deg[i][bucket] += 1;
    }

    /// Get the current degree counts for a node.
    #[inline]
    pub fn degrees(&self, i: usize) -> [u32; B] {
        self.deg[i]
    }

    /// Finalize the degree counting phase and prepare for scatter.
    ///
    /// This computes prefix sums and allocates the packed neighborhood array.
    /// Must be called after all `inc_degree` calls and before any `scatter` calls.
    pub fn finalize_degrees(&mut self) {
        // Compute prefix sums for node edge ranges
        self.node_edge_ranges.clear();
        self.node_edge_ranges.push(0);

        for i in 0..self.n {
            let total: u32 = self.deg[i].iter().sum();
            let last = *self.node_edge_ranges.last().unwrap();
            self.node_edge_ranges.push(last + total as usize);
        }

        // Allocate packed neighborhoods
        let total_edges = *self.node_edge_ranges.last().unwrap();
        self.neighborhoods = vec![0u32; total_edges];

        // Compute bucket bases and initialize cursors
        for i in 0..self.n {
            let start = self.node_edge_ranges[i];
            let mut offset = start;
            for b in 0..B {
                self.bucket_bases[i][b] = offset;
                self.cursors[i][b] = offset;
                offset += self.deg[i][b] as usize;
            }
        }
    }

    /// Scatter a neighbor into the packed storage.
    ///
    /// Call this for each edge after `finalize_degrees`.
    #[inline]
    pub fn scatter(&mut self, node: usize, bucket: usize, neighbor: u32) {
        debug_assert!(bucket < B, "bucket index out of range");
        debug_assert!(node < self.n, "node index out of range");
        let pos = self.cursors[node][bucket];
        self.neighborhoods[pos] = neighbor;
        self.cursors[node][bucket] += 1;
    }

    /// Sort all bucket segments for determinism.
    ///
    /// Call this after all `scatter` calls are complete.
    pub fn sort_all(&mut self) {
        for i in 0..self.n {
            for b in 0..B {
                let start = self.bucket_bases[i][b];
                let end = if b + 1 < B {
                    self.bucket_bases[i][b + 1]
                } else {
                    self.node_edge_ranges[i + 1]
                };
                self.neighborhoods[start..end].sort_unstable();
            }
        }
    }

    /// Build the final packed storage.
    ///
    /// Consumes the builder and returns the packed arrays.
    pub fn build(self) -> PackedBuckets<B> {
        PackedBuckets {
            node_edge_ranges: self.node_edge_ranges.into(),
            node_deg: self.deg.into(),
            neighborhoods: self.neighborhoods.into(),
        }
    }
}

/// Packed bucket storage for typed graph wrappers.
#[derive(Debug, Clone)]
pub struct PackedBuckets<const B: usize> {
    /// Prefix sums: `node_edge_ranges[i]..node_edge_ranges[i+1]` is node i's range.
    pub node_edge_ranges: Arc<[usize]>,
    /// Per-node bucket sizes.
    pub node_deg: Arc<[[u32; B]]>,
    /// Packed neighbor storage.
    pub neighborhoods: Arc<[u32]>,
}

impl<const B: usize> PackedBuckets<B> {
    /// Get the slice for a specific bucket of a node.
    #[inline]
    pub fn bucket_slice(&self, node: u32, bucket: usize) -> &[u32] {
        debug_assert!(bucket < B, "bucket index out of range");
        let node = node as usize;
        let start = self.node_edge_ranges[node];

        // Calculate bucket start offset
        let bucket_start: usize = self.node_deg[node][..bucket]
            .iter()
            .map(|&d| d as usize)
            .sum::<usize>()
            + start;

        // Calculate bucket end offset
        let bucket_end = bucket_start + self.node_deg[node][bucket] as usize;

        &self.neighborhoods[bucket_start..bucket_end]
    }

    /// Get all neighbors of a node (all buckets concatenated).
    #[inline]
    pub fn all_neighbors(&self, node: u32) -> &[u32] {
        let node = node as usize;
        let start = self.node_edge_ranges[node];
        let end = self.node_edge_ranges[node + 1];
        &self.neighborhoods[start..end]
    }

    /// Get the number of nodes.
    #[inline]
    pub fn n(&self) -> u32 {
        (self.node_edge_ranges.len() - 1) as u32
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn packed_buckets_builder_two_buckets() {
        // Simulate DAG-like structure: 2 buckets (parents, children)
        // Node 0: 1 parent (node 1), 2 children (nodes 2, 3)
        // Node 1: 0 parents, 1 child (node 0)
        // Node 2: 1 parent (node 0), 0 children
        // Node 3: 1 parent (node 0), 0 children

        let mut builder: PackedBucketsBuilder<2> = PackedBucketsBuilder::new(4);

        // Count degrees
        builder.inc_degree(0, 0); // node 0 has 1 parent
        builder.inc_degree(0, 1); // node 0 has 1 child
        builder.inc_degree(0, 1); // node 0 has 2nd child
        builder.inc_degree(1, 1); // node 1 has 1 child
        builder.inc_degree(2, 0); // node 2 has 1 parent
        builder.inc_degree(3, 0); // node 3 has 1 parent

        builder.finalize_degrees();

        // Scatter neighbors
        builder.scatter(0, 0, 1); // parent
        builder.scatter(0, 1, 2); // child 1
        builder.scatter(0, 1, 3); // child 2
        builder.scatter(1, 1, 0); // child
        builder.scatter(2, 0, 0); // parent
        builder.scatter(3, 0, 0); // parent

        builder.sort_all();
        let packed = builder.build();

        // Verify
        assert_eq!(packed.bucket_slice(0, 0), &[1]); // parents of 0
        assert_eq!(packed.bucket_slice(0, 1), &[2, 3]); // children of 0
        assert_eq!(packed.bucket_slice(1, 0), &[] as &[u32]); // parents of 1
        assert_eq!(packed.bucket_slice(1, 1), &[0]); // children of 1
        assert_eq!(packed.bucket_slice(2, 0), &[0]); // parents of 2
        assert_eq!(packed.bucket_slice(2, 1), &[] as &[u32]); // children of 2
    }

    #[test]
    fn packed_buckets_builder_three_buckets() {
        // Simulate PDAG-like structure: 3 buckets (parents, undirected, children)
        let mut builder: PackedBucketsBuilder<3> = PackedBucketsBuilder::new(3);

        builder.inc_degree(0, 2); // node 0 has 1 child
        builder.inc_degree(1, 0); // node 1 has 1 parent
        builder.inc_degree(1, 1); // node 1 has 1 undirected neighbor
        builder.inc_degree(2, 1); // node 2 has 1 undirected neighbor

        builder.finalize_degrees();

        builder.scatter(0, 2, 1); // child
        builder.scatter(1, 0, 0); // parent
        builder.scatter(1, 1, 2); // undirected
        builder.scatter(2, 1, 1); // undirected

        builder.sort_all();
        let packed = builder.build();

        assert_eq!(packed.bucket_slice(1, 0), &[0]); // parents of 1
        assert_eq!(packed.bucket_slice(1, 1), &[2]); // undirected of 1
        assert_eq!(packed.bucket_slice(1, 2), &[] as &[u32]); // children of 1
    }
}
