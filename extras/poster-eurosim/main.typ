#import "@preview/peace-of-posters:0.6.0" as pop

#let spacing = 1.2em
#set page("a0", margin: 1.5cm)

#pop.set-theme(pop.uni-fr)

#set text(size: pop.layout-a0.at("body-size"))

#let box-spacing = 1.2em
#set columns(gutter: box-spacing)
#set block(spacing: box-spacing)
#pop.update-poster-layout(spacing: box-spacing)

#set text(font: "New Computer Modern")
#show raw: set text(font: "New Computer Modern Mono")

#pop.title-box(
  text(weight: "bold")[caugi: Fast and Flexible Causal Graph Interface for R],
  authors: [
    Frederik Fabricius Bjerre¹²,
    Johan Larsson²,
    #text(weight: "bold")[Bjarke Hautop Kristensen]¹#super[†], \
    Michael C Sachs¹
  ],
  institutes: [
    ¹ Section of Biostatistics, University of Copenhagen, \
    ² Department of Mathematical Sciences, University of Copenhagen, \
    #super[†] #link("bjarke.kristensen@sund.ku.dk")
  ],
  // keywords: "R package, causal inference",
  logo: image("images/logo.svg", width: 132%),
)

#columns(2,[

  #pop.column-box(heading: "Motivation")[
    - Existing packages often rely on low-level representations (e.g., adjacency matrices) and are not built specifically for causal graphs.
    - Causal workflows often bounce between graph objects, adjacency matrices, and package-specific APIs.
    - *_caugi_ delivers* an expressive, safe, and efficient graph interface for causal inference.
  ]

  #pop.column-box(heading: "Key Contributions")[
    - *High-performance backend:* Rust implementation for fast, memory-safe graph
      traversal.
    - *Type-safe graph classes:* DAG, PDAG, ADMG,
      and UG constraints are enforced at the graph level.
    - *Expressive syntax:* Compose graphs with concise R formulas that read naturally.
    - *Scalable queries:* Efficient ancestry and neighborhood
      relations on large graphs.
  ]

  #pop.column-box(heading: "Basic Usage")[
    #columns(2, [
      Available on CRAN:
      ```R
      install.packages("caugi")
      library(caugi)
      ```
      Syntax like a picture in your head:
      ```R
      cg <- caugi(
        A %-->% B + C,
        B %-->% D,
        C %-->% D,
        class = "DAG"
      )
      plot(cg)
      ```
      #colbreak()
      #image("images/dag.pdf", width: 80%)
    ])
  ]

  #pop.column-box(heading: "Querying and Metrics")[
    - *Relational queries*: `parents()`, `ancestors()`, `neighbors()`, etc.  
    - *Structural queries*: `is_acyclic()`, `is_cpdag()`, etc.  
    - *Causal queries*: `adjustment_set()`, `d_separated()`, etc.  
    - *Graph metrics*: `shd()`, `aid()`, etc.
    
    *Example queries:*
    ```R
    > parents(cg, "D")
    [1] "B" "C"
    
    > d_separated(cg, "A", "D", Z = c("B", "D"))
    [1] TRUE
    ```
  ]

  #pop.column-box(heading: "How it Works", stretch-to-next: true)[
    - *Backend:* Rust for memory safety and performance.

    - *Storage:* Compressed Sparse Row (CSR)
      - Memory-efficient for sparse graphs
      - Direct slice access #sym.arrow $$O(1)$$ adjacency lookup

    - *Immutable + lazy rebuild:*  
      - Rebuilds in $$O(|V| + |E|)$$ on query after graph modification.

    - *Result:* Fast, predictable queries with consistent graph state.
  ]
  
  #colbreak()

  #pop.column-box(heading: "Graph-Class Safe")[
    - Type safety, but for graphs.
    - Supports DAGs, PDAGs, ADMGs, UGs, and unknown graphs.
    - All graph modifications are checked against class constraints.
      - For example, adding an edge that creates a cycle in a DAG is prevented.
    - Keeps graph state reliable and consistent throughout analysis.
  ]

  #pop.column-box(heading: "Benchmarks")[
    - Benchmarked _caugi_ against _bnlearn_, _dagitty_, and _igraph_.
      - We report median runtime.
    - _caugi_ consistently an order or two faster than alternatives.
  #set align(center)
  #image("images/dsep.svg", width: 80%)
  #image("images/ancestors_descendants.svg", width: 80%)
  ]
  #pop.column-box(heading: "Package Documentation", stretch-to-next: true)[
    - Pkgdown site: #link("https://caugi.org/")[caugi.org]
    #set align(center)
    #image("images/qr-url.pdf", width: 50%)
  ]
])

#pop.update-theme(
    heading-box-args: (
        fill: rgb(255, 255, 255),
        stroke: rgb(25, 25, 25),
    )
)

#pop.bottom-box(
	stack(
    dir: ltr,
    h(0.5fr),
		image(height: 120pt, "images/eurocim-icon.gif"),
    h(1fr),
		image(height: 120pt, "images/ku-logo.pdf"),
    h(1fr),
		image("images/smart-biomed.png", height: 120pt),
    h(0.5fr)
	)
)
