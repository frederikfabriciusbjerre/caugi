// SPDX-License-Identifier: MIT
//! GraphML serialization and deserialization for caugi graphs.

use crate::edges::EdgeRegistry;
use crate::graph::serialization::DeserializedGraph;
use crate::graph::view::GraphView;
use quick_xml::events::{BytesDecl, BytesEnd, BytesStart, BytesText, Event};
use quick_xml::{Reader, Writer};

/// Serialize a caugi graph to GraphML format.
pub fn serialize_graphml(
    graph: &GraphView,
    registry: &EdgeRegistry,
    graph_class: &str,
    node_names: Vec<String>,
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

    let mut writer = Writer::new_with_indent(Vec::new(), b' ', 2);

    // XML declaration
    writer
        .write_event(Event::Decl(BytesDecl::new("1.0", Some("UTF-8"), None)))
        .map_err(|e| e.to_string())?;

    // GraphML root element
    let mut graphml = BytesStart::new("graphml");
    graphml.push_attribute(("xmlns", "http://graphml.graphdrawing.org/xmlns"));
    graphml.push_attribute(("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance"));
    graphml.push_attribute((
        "xsi:schemaLocation",
        "http://graphml.graphdrawing.org/xmlns http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd",
    ));
    writer
        .write_event(Event::Start(graphml))
        .map_err(|e| e.to_string())?;

    // Key definitions
    let mut key_edge = BytesStart::new("key");
    key_edge.push_attribute(("id", "edge_type"));
    key_edge.push_attribute(("for", "edge"));
    key_edge.push_attribute(("attr.name", "edge_type"));
    key_edge.push_attribute(("attr.type", "string"));
    writer
        .write_event(Event::Empty(key_edge))
        .map_err(|e| e.to_string())?;

    let mut key_graph = BytesStart::new("key");
    key_graph.push_attribute(("id", "graph_class"));
    key_graph.push_attribute(("for", "graph"));
    key_graph.push_attribute(("attr.name", "graph_class"));
    key_graph.push_attribute(("attr.type", "string"));
    writer
        .write_event(Event::Empty(key_graph))
        .map_err(|e| e.to_string())?;

    // Graph element
    let mut graph_elem = BytesStart::new("graph");
    graph_elem.push_attribute(("id", "G"));
    graph_elem.push_attribute(("edgedefault", "directed"));
    writer
        .write_event(Event::Start(graph_elem.clone()))
        .map_err(|e| e.to_string())?;

    // Graph class data
    let mut data = BytesStart::new("data");
    data.push_attribute(("key", "graph_class"));
    writer
        .write_event(Event::Start(data.clone()))
        .map_err(|e| e.to_string())?;
    writer
        .write_event(Event::Text(BytesText::new(graph_class)))
        .map_err(|e| e.to_string())?;
    writer
        .write_event(Event::End(BytesEnd::new("data")))
        .map_err(|e| e.to_string())?;

    // Nodes
    for name in &node_names {
        let mut node = BytesStart::new("node");
        node.push_attribute(("id", name.as_str()));
        writer
            .write_event(Event::Empty(node))
            .map_err(|e| e.to_string())?;
    }

    // Edges (with deduplication for symmetric edges)
    let mut seen = std::collections::HashSet::new();

    for i in 0..n {
        let rng = core.row_range(i as u32);
        for k in rng {
            let j = core.col_index[k] as usize;
            let edge_id = core.etype[k];
            let side = core.side[k];
            let edge_spec = registry.spec_of_code(edge_id).map_err(|e| e.to_string())?;

            // Deduplication logic (same as serialization.rs)
            if edge_spec.symmetric {
                let (a, b) = if i <= j { (i, j) } else { (j, i) };
                let key = (a, b, edge_id);
                if !seen.insert(key) {
                    continue;
                }
            } else {
                if side != 0 {
                    continue;
                }
                let key = (i, j, edge_id);
                seen.insert(key);
            }

            let from = &node_names[i];
            let to = &node_names[j];
            let edge_type = &edge_spec.glyph;

            let mut edge = BytesStart::new("edge");
            edge.push_attribute(("source", from.as_str()));
            edge.push_attribute(("target", to.as_str()));
            writer
                .write_event(Event::Start(edge.clone()))
                .map_err(|e| e.to_string())?;

            // Edge type data
            let mut data = BytesStart::new("data");
            data.push_attribute(("key", "edge_type"));
            writer
                .write_event(Event::Start(data.clone()))
                .map_err(|e| e.to_string())?;
            writer
                .write_event(Event::Text(BytesText::new(edge_type)))
                .map_err(|e| e.to_string())?;
            writer
                .write_event(Event::End(BytesEnd::new("data")))
                .map_err(|e| e.to_string())?;

            writer
                .write_event(Event::End(BytesEnd::new("edge")))
                .map_err(|e| e.to_string())?;
        }
    }

    // Close graph and graphml
    writer
        .write_event(Event::End(BytesEnd::new("graph")))
        .map_err(|e| e.to_string())?;
    writer
        .write_event(Event::End(BytesEnd::new("graphml")))
        .map_err(|e| e.to_string())?;

    String::from_utf8(writer.into_inner()).map_err(|e| e.to_string())
}

/// Deserialize a GraphML graph.
/// Deserialize a GraphML graph.
pub fn deserialize_graphml(
    xml: &str,
    registry: &EdgeRegistry,
) -> Result<DeserializedGraph, String> {
    let mut reader = Reader::from_str(xml);
    reader.config_mut().trim_text(true);

    let mut nodes: Vec<String> = Vec::new();
    let mut edges_from: Vec<String> = Vec::new();
    let mut edges_to: Vec<String> = Vec::new();
    let mut edges_type: Vec<String> = Vec::new();
    let mut graph_class: String = "UNKNOWN".to_string();

    // Track whether we're inside the main <graph> element (depth == 1)
    let mut graph_depth: usize = 0;

    // Edge state (only valid while in_edge == true)
    let mut in_edge = false;
    let mut current_edge_from = String::new();
    let mut current_edge_to = String::new();
    let mut edge_type_seen = false;

    // <data> state: accumulate content across Text + GeneralRef
    let mut in_data = false;
    let mut data_key = String::new();
    let mut data_value = String::new();

    let mut buf: Vec<u8> = Vec::new();

    fn push_general_ref(out: &mut String, name: &[u8]) {
        match name {
            b"lt" => out.push('<'),
            b"gt" => out.push('>'),
            b"amp" => out.push('&'),
            b"apos" => out.push('\''),
            b"quot" => out.push('"'),
            _ => {
                // Don’t silently drop unknown entity refs
                out.push('&');
                out.push_str(&String::from_utf8_lossy(name));
                out.push(';');
            }
        }
    }

    fn push_node_from_attrs(nodes: &mut Vec<String>, e: &BytesStart) -> Result<(), String> {
        for attr in e.attributes() {
            let attr = attr.map_err(|e| e.to_string())?;
            if attr.key.as_ref() == b"id" {
                let v = attr.unescape_value().map_err(|e| e.to_string())?;
                nodes.push(v.into_owned());
                break;
            }
        }
        Ok(())
    }

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(e)) => match e.name().as_ref() {
                b"graph" => {
                    graph_depth += 1;
                }

                b"node" if graph_depth == 1 => {
                    push_node_from_attrs(&mut nodes, &e)?;
                }

                b"edge" if graph_depth == 1 => {
                    in_edge = true;
                    edge_type_seen = false;
                    current_edge_from.clear();
                    current_edge_to.clear();

                    for attr in e.attributes() {
                        let attr = attr.map_err(|e| e.to_string())?;
                        match attr.key.as_ref() {
                            b"source" => {
                                let v = attr.unescape_value().map_err(|e| e.to_string())?;
                                current_edge_from = v.into_owned();
                            }
                            b"target" => {
                                let v = attr.unescape_value().map_err(|e| e.to_string())?;
                                current_edge_to = v.into_owned();
                            }
                            _ => {}
                        }
                    }
                }

                b"data" if graph_depth == 1 => {
                    in_data = true;
                    data_key.clear();
                    data_value.clear();

                    for attr in e.attributes() {
                        let attr = attr.map_err(|e| e.to_string())?;
                        if attr.key.as_ref() == b"key" {
                            let v = attr.unescape_value().map_err(|e| e.to_string())?;
                            data_key = v.into_owned();
                        }
                    }
                }

                _ => {}
            },

            Ok(Event::Empty(e)) => match e.name().as_ref() {
                b"node" if graph_depth == 1 => {
                    push_node_from_attrs(&mut nodes, &e)?;
                }
                _ => {}
            },

            Ok(Event::Text(e)) => {
                if in_data {
                    let t = e.decode().map_err(|e| e.to_string())?;
                    data_value.push_str(&t);
                }
            }

            Ok(Event::GeneralRef(e)) => {
                if in_data {
                    push_general_ref(&mut data_value, e.as_ref());
                }
            }

            Ok(Event::End(e)) => match e.name().as_ref() {
                b"graph" => {
                    if graph_depth > 0 {
                        graph_depth -= 1;
                    }
                }

                b"data" => {
                    if in_data {
                        in_data = false;

                        // Interpret the full <data> payload here (after Text+GeneralRef accumulation)
                        if data_key == "graph_class" && !in_edge {
                            graph_class = data_value.clone();
                        } else if data_key == "edge_type" && in_edge {
                            let value = data_value.clone();

                            if registry.code_of(&value).is_err() {
                                return Err(format!("Unknown edge type: {}", value));
                            }

                            if !edge_type_seen {
                                edges_from.push(current_edge_from.clone());
                                edges_to.push(current_edge_to.clone());
                                edges_type.push(value);
                                edge_type_seen = true;
                            } else if let Some(last) = edges_type.last_mut() {
                                // In case multiple edge_type fields appear, keep the latest
                                *last = value;
                            }
                        }

                        data_key.clear();
                        data_value.clear();
                    }
                }

                b"edge" => {
                    if in_edge && !edge_type_seen {
                        let default = "-->";
                        if registry.code_of(default).is_err() {
                            return Err(format!("Unknown default edge type: {}", default));
                        }
                        edges_from.push(current_edge_from.clone());
                        edges_to.push(current_edge_to.clone());
                        edges_type.push(default.to_string());
                    }

                    in_edge = false;
                    edge_type_seen = false;
                    current_edge_from.clear();
                    current_edge_to.clear();
                }

                _ => {}
            },

            Ok(Event::Eof) => break,
            Err(e) => return Err(format!("XML parsing error: {}", e)),
            _ => {}
        }

        buf.clear();
    }

    // Validate all nodes exist in edges
    let node_set: std::collections::HashSet<_> = nodes.iter().cloned().collect();
    for from in &edges_from {
        if !node_set.contains(from) {
            return Err(format!("Unknown node in edge: {}", from));
        }
    }
    for to in &edges_to {
        if !node_set.contains(to) {
            return Err(format!("Unknown node in edge: {}", to));
        }
    }

    Ok(DeserializedGraph {
        nodes,
        edges_from,
        edges_to,
        edges_type,
        graph_class,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    fn setup() -> EdgeRegistry {
        let mut reg = EdgeRegistry::new();
        use crate::edges::{EdgeClass, EdgeSpec, Mark};
        reg.register(EdgeSpec {
            glyph: "-->".to_string(),
            tail: Mark::Tail,
            head: Mark::Arrow,
            symmetric: false,
            class: EdgeClass::Directed,
        })
        .unwrap();
        reg.register(EdgeSpec {
            glyph: "---".to_string(),
            tail: Mark::Tail,
            head: Mark::Tail,
            symmetric: true,
            class: EdgeClass::Undirected,
        })
        .unwrap();
        reg.register(EdgeSpec {
            glyph: "<->".to_string(),
            tail: Mark::Arrow,
            head: Mark::Arrow,
            symmetric: true,
            class: EdgeClass::Bidirected,
        })
        .unwrap();
        reg.register(EdgeSpec {
            glyph: "o->".to_string(),
            tail: Mark::Circle,
            head: Mark::Arrow,
            symmetric: false,
            class: EdgeClass::PartiallyDirected,
        })
        .unwrap();
        reg
    }

    #[test]
    fn test_serialize_simple_dag() {
        let reg = setup();
        let dir = reg.code_of("-->").unwrap();

        let mut builder = GraphBuilder::new_with_registry(3, true, &reg);
        builder.add_edge(0, 1, dir).unwrap();
        builder.add_edge(1, 2, dir).unwrap();

        let graph = builder.finalize().unwrap();
        let view = GraphView::Raw(std::sync::Arc::new(graph));

        let node_names = vec!["A".to_string(), "B".to_string(), "C".to_string()];
        let xml = serialize_graphml(&view, &reg, "DAG", node_names).unwrap();

        assert!(xml.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"));
        assert!(xml.contains("<graphml"));
        assert!(xml.contains("<graph"));
        assert!(xml.contains("edgedefault=\"directed\""));
        assert!(xml.contains("<node id=\"A\""));
        assert!(xml.contains("<node id=\"B\""));
        assert!(xml.contains("<node id=\"C\""));
        assert!(xml.contains("<edge source=\"A\" target=\"B\""));
        assert!(xml.contains("<edge source=\"B\" target=\"C\""));
        assert!(xml.contains("<data key=\"edge_type\">--&gt;</data>"));
    }

    #[test]
    fn test_serialize_with_special_chars() {
        let reg = setup();
        let dir = reg.code_of("-->").unwrap();

        let mut builder = GraphBuilder::new_with_registry(2, true, &reg);
        builder.add_edge(0, 1, dir).unwrap();

        let graph = builder.finalize().unwrap();
        let view = GraphView::Raw(std::sync::Arc::new(graph));

        let node_names = vec!["A&B".to_string(), "C<D".to_string()];
        let xml = serialize_graphml(&view, &reg, "DAG", node_names).unwrap();

        assert!(xml.contains("A&amp;B"));
        assert!(xml.contains("C&lt;D"));
    }

    #[test]
    fn test_serialize_different_edge_types() {
        let reg = setup();
        let dir = reg.code_of("-->").unwrap();
        let undir = reg.code_of("---").unwrap();
        let bidir = reg.code_of("<->").unwrap();

        let mut builder = GraphBuilder::new_with_registry(4, true, &reg);
        builder.add_edge(0, 1, dir).unwrap();
        builder.add_edge(1, 2, undir).unwrap();
        builder.add_edge(2, 3, bidir).unwrap();

        let graph = builder.finalize().unwrap();
        let view = GraphView::Raw(std::sync::Arc::new(graph));

        let node_names = vec![
            "A".to_string(),
            "B".to_string(),
            "C".to_string(),
            "D".to_string(),
        ];
        let xml = serialize_graphml(&view, &reg, "UNKNOWN", node_names).unwrap();

        assert!(xml.contains("--&gt;"));
        assert!(xml.contains("---"));
        assert!(xml.contains("&lt;-&gt;"));
    }

    #[test]
    fn test_deserialize_simple_dag() {
        let reg = setup();

        let xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<graphml xmlns="http://graphml.graphdrawing.org/xmlns">
  <key id="edge_type" for="edge" attr.name="edge_type" attr.type="string"/>
  <key id="graph_class" for="graph" attr.name="graph_class" attr.type="string"/>
  <graph id="G" edgedefault="directed">
    <data key="graph_class">DAG</data>
    <node id="A"/>
    <node id="B"/>
    <node id="C"/>
    <edge source="A" target="B">
      <data key="edge_type">--&gt;</data>
    </edge>
    <edge source="B" target="C">
      <data key="edge_type">--&gt;</data>
    </edge>
  </graph>
</graphml>"#;

        let result = deserialize_graphml(xml, &reg).unwrap();

        assert_eq!(result.nodes, vec!["A", "B", "C"]);
        assert_eq!(result.edges_from, vec!["A", "B"]);
        assert_eq!(result.edges_to, vec!["B", "C"]);
        assert_eq!(result.edges_type, vec!["-->", "-->"]);
        assert_eq!(result.graph_class, "DAG");
    }

    #[test]
    fn test_deserialize_with_special_chars() {
        let reg = setup();

        let xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<graphml xmlns="http://graphml.graphdrawing.org/xmlns">
  <graph id="G" edgedefault="directed">
    <node id="A&amp;B"/>
    <node id="C&lt;D"/>
    <edge source="A&amp;B" target="C&lt;D">
      <data key="edge_type">--&gt;</data>
    </edge>
  </graph>
</graphml>"#;

        let result = deserialize_graphml(xml, &reg).unwrap();

        assert_eq!(result.nodes, vec!["A&B", "C<D"]);
        assert_eq!(result.edges_from, vec!["A&B"]);
        assert_eq!(result.edges_to, vec!["C<D"]);
    }

    #[test]
    fn test_deserialize_default_edge_type() {
        let reg = setup();

        let xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<graphml xmlns="http://graphml.graphdrawing.org/xmlns">
  <graph id="G" edgedefault="directed">
    <node id="A"/>
    <node id="B"/>
    <edge source="A" target="B">
      <data key="edge_type">--&gt;</data>
    </edge>
  </graph>
</graphml>"#;

        let result = deserialize_graphml(xml, &reg).unwrap();

        assert_eq!(result.edges_type, vec!["-->"]);
    }

    #[test]
    fn test_deserialize_unknown_node_error() {
        let reg = setup();

        let xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<graphml xmlns="http://graphml.graphdrawing.org/xmlns">
  <graph id="G" edgedefault="directed">
    <node id="A"/>
    <edge source="A" target="B">
      <data key="edge_type">--&gt;</data>
    </edge>
  </graph>
</graphml>"#;

        let result = deserialize_graphml(xml, &reg);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Unknown node"));
    }

    #[test]
    fn test_roundtrip() {
        let reg = setup();
        let dir = reg.code_of("-->").unwrap();
        let undir = reg.code_of("---").unwrap();

        let mut builder = GraphBuilder::new_with_registry(3, true, &reg);
        builder.add_edge(0, 1, dir).unwrap();
        builder.add_edge(1, 2, undir).unwrap();

        let graph = builder.finalize().unwrap();
        let view = GraphView::Raw(std::sync::Arc::new(graph));

        let node_names = vec!["A".to_string(), "B".to_string(), "C".to_string()];
        let xml = serialize_graphml(&view, &reg, "UNKNOWN", node_names.clone()).unwrap();

        let deserialized = deserialize_graphml(&xml, &reg).unwrap();

        assert_eq!(deserialized.nodes, node_names);
        assert_eq!(deserialized.edges_from, vec!["A", "B"]);
        assert_eq!(deserialized.edges_to, vec!["B", "C"]);
        assert_eq!(deserialized.edges_type, vec!["-->", "---"]);
        assert_eq!(deserialized.graph_class, "UNKNOWN");
    }

    #[test]
    fn test_serialize_empty_graph() {
        let reg = setup();
        let builder = GraphBuilder::new_with_registry(2, true, &reg);
        let graph = builder.finalize().unwrap();
        let view = GraphView::Raw(std::sync::Arc::new(graph));

        let node_names = vec!["A".to_string(), "B".to_string()];
        let xml = serialize_graphml(&view, &reg, "DAG", node_names).unwrap();

        assert!(xml.contains("<node id=\"A\""));
        assert!(xml.contains("<node id=\"B\""));
        assert!(!xml.contains("<edge"));
    }

    #[test]
    fn test_deserialize_empty_graph() {
        let reg = setup();

        let xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<graphml xmlns="http://graphml.graphdrawing.org/xmlns">
  <graph id="G" edgedefault="directed">
    <node id="A"/>
    <node id="B"/>
  </graph>
</graphml>"#;

        let result = deserialize_graphml(xml, &reg).unwrap();

        assert_eq!(result.nodes, vec!["A", "B"]);
        assert!(result.edges_from.is_empty());
        assert!(result.edges_to.is_empty());
        assert!(result.edges_type.is_empty());
    }
}
