// SPDX-License-Identifier: MIT
//! Serialization and deserialization for caugi graphs.

use crate::edges::EdgeRegistry;
use crate::graph::view::GraphView;
use serde::{Deserialize, Serialize};
use std::io::{Read, Write};

/// Deserialized graph data
#[derive(Debug)]
pub struct DeserializedGraph {
    pub nodes: Vec<String>,
    pub edges_from: Vec<String>,
    pub edges_to: Vec<String>,
    pub edges_type: Vec<String>,
    pub graph_class: String,
}

#[derive(Serialize, Deserialize)]
struct CaugiFormat {
    #[serde(rename = "$schema", skip_serializing_if = "Option::is_none")]
    schema: Option<String>,
    format: String,
    version: String,
    graph: GraphData,
    #[serde(skip_serializing_if = "Option::is_none")]
    meta: Option<MetaData>,
}

#[derive(Serialize, Deserialize)]
struct GraphData {
    class: String,
    nodes: Vec<String>,
    edges: Vec<EdgeData>,
}

#[derive(Serialize, Deserialize)]
struct EdgeData {
    from: String,
    to: String,
    edge: String,
}

#[derive(Serialize, Deserialize)]
struct MetaData {
    #[serde(skip_serializing_if = "Option::is_none")]
    comment: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    tags: Option<Vec<String>>,
}

/// Serialize a caugi graph to JSON format.
pub fn serialize_caugi(
    graph: &GraphView,
    registry: &EdgeRegistry,
    graph_class: &str,
    node_names: Vec<String>,
    comment: Option<String>,
    tags: Option<Vec<String>>,
) -> Result<String, String> {
    let core = graph.core();
    let n = node_names.len();

    if n != core.n() as usize {
        return Err(format!(
            "Node names length ({}) does not match graph size ({})",
            n,
            core.n()
        ));
    }

    let mut edges = Vec::new();
    let mut seen = std::collections::HashSet::new();

    for i in 0..n {
        let rng = core.row_range(i as u32);
        for k in rng {
            let j = core.col_index[k] as usize;
            let edge_id = core.etype[k];
            let side = core.side[k]; // 0=tail-ish, 1=head-ish
            let edge_spec = registry.spec_of_code(edge_id).map_err(|e| e.to_string())?;

            // For symmetric edges, only output once (when i <= j)
            // For directed edges, only output from the tail side (side == 0)
            if edge_spec.symmetric {
                let (a, b) = if i <= j { (i, j) } else { (j, i) };
                let key = (a, b, edge_id);
                if !seen.insert(key) {
                    continue;
                }
            } else {
                // For asymmetric edges, only output from tail side
                if side != 0 {
                    continue;
                }
                let key = (i, j, edge_id);
                seen.insert(key);
            }

            let from = node_names[i].clone();
            let to = node_names[j].clone();
            let edge = edge_spec.glyph.clone();
            edges.push(EdgeData { from, to, edge });
        }
    }

    let meta = if comment.is_some() || tags.is_some() {
        Some(MetaData { comment, tags })
    } else {
        None
    };

    let caugi_format = CaugiFormat {
        schema: Some("https://caugi.org/schemas/caugi-v1.schema.json".to_string()),
        format: "caugi".to_string(),
        version: "1.0.0".to_string(),
        graph: GraphData {
            class: graph_class.to_string(),
            nodes: node_names,
            edges,
        },
        meta,
    };

    serde_json::to_string_pretty(&caugi_format).map_err(|e| e.to_string())
}

pub fn deserialize_caugi(json: &str, registry: &EdgeRegistry) -> Result<DeserializedGraph, String> {
    let caugi_format: CaugiFormat = serde_json::from_str(json).map_err(|e| e.to_string())?;

    if caugi_format.format != "caugi" {
        return Err(format!(
            "Invalid format: expected 'caugi', got '{}'",
            caugi_format.format
        ));
    }

    // Parse version (semver: major.minor.patch)
    let parts: Vec<&str> = caugi_format.version.split('.').collect();
    let major = parts
        .get(0)
        .and_then(|s| s.parse::<u32>().ok())
        .unwrap_or(0);

    // Check major version compatibility
    if major != 1 {
        return Err(format!(
            "Incompatible format version: {}. This package supports version 1.x.x. \
             Please update the caugi package to read version {} files.",
            caugi_format.version, major
        ));
    }

    // Minor/patch differences are compatible (forward and backward)

    let graph_data = caugi_format.graph;

    // Validate all nodes exist
    let node_set: std::collections::HashSet<_> = graph_data.nodes.iter().cloned().collect();
    for edge_data in &graph_data.edges {
        if !node_set.contains(&edge_data.from) {
            return Err(format!("Unknown node in edge: {}", edge_data.from));
        }
        if !node_set.contains(&edge_data.to) {
            return Err(format!("Unknown node in edge: {}", edge_data.to));
        }
        // Validate edge type exists in registry
        if registry.code_of(&edge_data.edge).is_err() {
            return Err(format!("Unknown edge type: {}", edge_data.edge));
        }
    }

    // Extract edge components
    let edges_from: Vec<String> = graph_data.edges.iter().map(|e| e.from.clone()).collect();
    let edges_to: Vec<String> = graph_data.edges.iter().map(|e| e.to.clone()).collect();
    let edges_type: Vec<String> = graph_data.edges.iter().map(|e| e.edge.clone()).collect();

    Ok(DeserializedGraph {
        nodes: graph_data.nodes,
        edges_from,
        edges_to,
        edges_type,
        graph_class: graph_data.class,
    })
}

pub fn write_caugi_file(
    graph: &GraphView,
    registry: &EdgeRegistry,
    graph_class: &str,
    node_names: Vec<String>,
    path: &str,
    comment: Option<String>,
    tags: Option<Vec<String>>,
) -> Result<(), String> {
    let json = serialize_caugi(graph, registry, graph_class, node_names, comment, tags)?;
    let mut file = std::fs::File::create(path).map_err(|e| e.to_string())?;
    file.write_all(json.as_bytes()).map_err(|e| e.to_string())?;
    file.write_all(b"\n").map_err(|e| e.to_string())?;
    Ok(())
}

pub fn read_caugi_file(path: &str, registry: &EdgeRegistry) -> Result<DeserializedGraph, String> {
    let mut file = std::fs::File::open(path).map_err(|e| e.to_string())?;
    let mut json = String::new();
    file.read_to_string(&mut json).map_err(|e| e.to_string())?;
    deserialize_caugi(&json, registry)
}
