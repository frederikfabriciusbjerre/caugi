# to_dot() output

    Code
      cat(as.character(to_dot(snapshot_graph)))
    Output
      digraph {
      
        // Nodes
        A;
        B;
        C;
        "my var";
        D;
        E;
      
        // Edges
        A -> B;
        B -> C [dir="none"];
        C -> D [dir="both"];
        "my var" -> A [dir="both", arrowtail="odot"];
      }

# to_mermaid() output

    Code
      cat(as.character(to_mermaid(snapshot_graph)))
    Output
      flowchart TD
        A --> B
        B --- C
        C <--> D
        "my var" o--> A

# to_graphml() output

    Code
      cat(as.character(to_graphml(snapshot_graph)))
    Output
      <?xml version="1.0" encoding="UTF-8"?>
      <graphml xmlns="http://graphml.graphdrawing.org/xmlns" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://graphml.graphdrawing.org/xmlns http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd">
        <key id="edge_type" for="edge" attr.name="edge_type" attr.type="string"/>
        <key id="graph_class" for="graph" attr.name="graph_class" attr.type="string"/>
        <graph id="G" edgedefault="directed">
          <data key="graph_class">UNKNOWN</data>
          <node id="A"/>
          <node id="B"/>
          <node id="C"/>
          <node id="my var"/>
          <node id="D"/>
          <node id="E"/>
          <edge source="A" target="B">
            <data key="edge_type">--&gt;</data>
          </edge>
          <edge source="B" target="C">
            <data key="edge_type">---</data>
          </edge>
          <edge source="C" target="D">
            <data key="edge_type">&lt;-&gt;</data>
          </edge>
          <edge source="my var" target="A">
            <data key="edge_type">o-&gt;</data>
          </edge>
        </graph>
      </graphml>

# caugi_serialize() output

    Code
      cat(caugi_serialize(snapshot_graph, comment = "c", tags = "t"))
    Output
      {
        "$schema": "https://caugi.org/schemas/caugi-v1.schema.json",
        "format": "caugi",
        "version": "1.0.0",
        "graph": {
          "class": "UNKNOWN",
          "nodes": [
            "A",
            "B",
            "C",
            "my var",
            "D",
            "E"
          ],
          "edges": [
            {
              "from": "A",
              "to": "B",
              "edge": "-->"
            },
            {
              "from": "B",
              "to": "C",
              "edge": "---"
            },
            {
              "from": "C",
              "to": "D",
              "edge": "<->"
            },
            {
              "from": "my var",
              "to": "A",
              "edge": "o->"
            }
          ]
        },
        "meta": {
          "comment": "c",
          "tags": [
            "t"
          ]
        }
      }

