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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::graph::builder::GraphBuilder;
    use crate::graph::dag::Dag;
    use crate::graph::pdag::Pdag;
    use std::sync::Arc;

    fn make_registry() -> EdgeRegistry {
        let mut reg = EdgeRegistry::new();
        reg.register_builtins().unwrap();
        reg
    }

    fn make_dag_view(reg: &EdgeRegistry) -> GraphView {
        let d = reg.code_of("-->").unwrap();
        let mut b = GraphBuilder::new(3, true, reg);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        let core = Arc::new(b.finalize().unwrap());
        GraphView::Dag(Arc::new(Dag::new(core).unwrap()))
    }

    fn make_pdag_with_undirected(reg: &EdgeRegistry) -> GraphView {
        let u = reg.code_of("---").unwrap();
        let mut b = GraphBuilder::new(2, true, reg);
        b.add_edge(0, 1, u).unwrap();
        let core = Arc::new(b.finalize().unwrap());
        GraphView::Pdag(Arc::new(Pdag::new(core).unwrap()))
    }

    #[test]
    fn serialize_deserialize_roundtrip_for_dag() {
        let reg = make_registry();
        let view = make_dag_view(&reg);
        let names = vec!["X".to_string(), "Y".to_string(), "Z".to_string()];

        let json = serialize_caugi(
            &view,
            &reg,
            "DAG",
            names.clone(),
            Some("example".to_string()),
            Some(vec!["a".to_string(), "b".to_string()]),
        )
        .unwrap();

        assert!(json.contains("\"format\": \"caugi\""));
        assert!(json.contains("\"class\": \"DAG\""));
        assert!(json.contains("\"comment\": \"example\""));
        assert!(json.contains("\"tags\""));

        let parsed = deserialize_caugi(&json, &reg).unwrap();
        assert_eq!(parsed.nodes, names);
        assert_eq!(parsed.graph_class, "DAG");
        assert_eq!(parsed.edges_from, vec!["X".to_string(), "Y".to_string()]);
        assert_eq!(parsed.edges_to, vec!["Y".to_string(), "Z".to_string()]);
        assert_eq!(
            parsed.edges_type,
            vec!["-->".to_string(), "-->".to_string()]
        );
    }

    #[test]
    fn serialize_symmetric_edges_are_written_once() {
        let reg = make_registry();
        let view = make_pdag_with_undirected(&reg);
        let json = serialize_caugi(
            &view,
            &reg,
            "PDAG",
            vec!["A".to_string(), "B".to_string()],
            None,
            None,
        )
        .unwrap();

        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();
        let edges = parsed["graph"]["edges"].as_array().unwrap();
        assert_eq!(edges.len(), 1);
        assert_eq!(edges[0]["from"], "A");
        assert_eq!(edges[0]["to"], "B");
        assert_eq!(edges[0]["edge"], "---");
    }

    #[test]
    fn serialize_rejects_wrong_name_length() {
        let reg = make_registry();
        let view = make_dag_view(&reg);
        let err =
            serialize_caugi(&view, &reg, "DAG", vec!["X".to_string()], None, None).unwrap_err();
        assert!(err.contains("Node names length (1) does not match graph size (3)"));
    }

    #[test]
    fn deserialize_rejects_invalid_payloads() {
        let reg = make_registry();

        let bad_format = r#"{
          "format":"not-caugi",
          "version":"1.0.0",
          "graph":{"class":"DAG","nodes":["A"],"edges":[]}
        }"#;
        assert!(deserialize_caugi(bad_format, &reg)
            .unwrap_err()
            .contains("Invalid format"));

        let bad_version = r#"{
          "format":"caugi",
          "version":"2.0.0",
          "graph":{"class":"DAG","nodes":["A"],"edges":[]}
        }"#;
        assert!(deserialize_caugi(bad_version, &reg)
            .unwrap_err()
            .contains("Incompatible format version"));

        let bad_node = r#"{
          "format":"caugi",
          "version":"1.0.0",
          "graph":{
            "class":"DAG",
            "nodes":["A"],
            "edges":[{"from":"A","to":"B","edge":"-->"}]
          }
        }"#;
        assert!(deserialize_caugi(bad_node, &reg)
            .unwrap_err()
            .contains("Unknown node in edge: B"));

        let bad_from = r#"{
          "format":"caugi",
          "version":"1.0.0",
          "graph":{
            "class":"DAG",
            "nodes":["A"],
            "edges":[{"from":"B","to":"A","edge":"-->"}]
          }
        }"#;
        assert!(deserialize_caugi(bad_from, &reg)
            .unwrap_err()
            .contains("Unknown node in edge: B"));

        let bad_edge = r#"{
          "format":"caugi",
          "version":"1.0.0",
          "graph":{
            "class":"DAG",
            "nodes":["A","B"],
            "edges":[{"from":"A","to":"B","edge":"??"}]
          }
        }"#;
        assert!(deserialize_caugi(bad_edge, &reg)
            .unwrap_err()
            .contains("Unknown edge type: ??"));
    }

    #[test]
    fn write_and_read_file_roundtrip_and_file_errors() {
        let reg = make_registry();
        let view = make_dag_view(&reg);
        let names = vec!["X".to_string(), "Y".to_string(), "Z".to_string()];

        let mut out = std::env::temp_dir();
        out.push(format!(
            "caugi-serialization-{}-{}.json",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));

        write_caugi_file(
            &view,
            &reg,
            "DAG",
            names.clone(),
            out.to_str().unwrap(),
            Some("saved".to_string()),
            None,
        )
        .unwrap();

        let back = read_caugi_file(out.to_str().unwrap(), &reg).unwrap();
        assert_eq!(back.nodes, names);
        assert_eq!(back.graph_class, "DAG");
        assert_eq!(back.edges_type, vec!["-->".to_string(), "-->".to_string()]);

        let _ = std::fs::remove_file(&out);

        let read_err = read_caugi_file("/definitely/not/a/real/path.json", &reg).unwrap_err();
        assert!(!read_err.is_empty());

        let write_err = write_caugi_file(
            &view,
            &reg,
            "DAG",
            vec!["X".to_string(), "Y".to_string(), "Z".to_string()],
            "/definitely/not/a/real/dir/out.json",
            None,
            None,
        )
        .unwrap_err();
        assert!(!write_err.is_empty());
    }
}
