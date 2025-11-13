# Performance

This vignette discusses the performance characteristics of `caugi`
including a comparison to the popular [`igraph`](https://r.igraph.org/),
[`bnlearn`](https://www.bnlearn.com/),
[`dagitty`](https://dagitty.net/), and
[`ggm`](https://cran.r-project.org/package=ggm). We focus on the
practical trade-offs that arise from different core data structures and
design choices.

The headline is: `caugi` frontloads computation. That is, `caugi` spends
more effort when constructing a graph and preparing indexes, so that
queries are wicked fast. The high performance is also due to the Rust
backend.

### Design choices

#### Compressed Sparse Row (CSR) representation

The core data structure in `caugi` is a compressed sparse row (CSR)
representation of the graph. CSR representations store for each vertex a
contiguous slice of neighbor IDs with a pointer (offset) array that
marks the start/end of each slice. This format is memory efficient for
sparse graphs. The `caugi` graph object also stores important query
information in the object, leading to parent, child, and neighbor
queries being done in $\mathcal{O}(1)$. This yields a larger memory
footprint, but the trade-off is that queries are extremely fast.

#### Mutation and lazy building

The `caugi` graph objects are expensive to build. This is the
performance downside of using `caugi`. For each time we make a
modification to a `caugi` graph object, we need to rebuild the graph
completely since the graph object is immutable by design. This has
complexity $\mathcal{O}\left( |V| + |E| \right)$, where $V$ is the
vertex set and $E$ is the edge set.

However, the graph object will only be rebuilt when the user either
calls
[`build()`](https://frederikfabriciusbjerre.github.io/caugi/reference/build.md)
directly or queries the graph. Therefore, you do not need to worry about
wasting compute time by iteratively making changes to a `caugi` graph
object, as the graph rebuilds lazily when queried. By doing this,
`caugi` graphs *feel* mutable, but, in reality, they are not.

By doing it this way, we ensure - that the graph object is always in a
consistent state when queried, and - that queries are as fast as
possible, while keeping the user experience smooth.

### Comparison

#### Setup

``` r
set.seed(42)
```

We are limiting ourselves to comparing graphs up to size $n = 1000$, as
the conversion to `bnlearn` and `dagitty` become prohibitively slow for
larger graphs.

``` r
generate_graphs <- function(n, p) {
  cg <- caugi::generate_graph(n = n, p = p, class = "DAG")
  ig <- caugi::as_igraph(cg)
  ggmg <- caugi::as_adjacency(cg)
  bng <- caugi::as_bnlearn(cg)
  dg <- caugi::as_dagitty(cg)
  list(cg = cg, ig = ig, ggmg = ggmg, bng = bng, dg = dg)
}
```

#### Relational queries

We start with parents/children:

``` r
graphs <- generate_graphs(1000, p = 0.25) # dense graph
cg <- graphs$cg
ig <- graphs$ig
ggmg <- graphs$ggmg
bng <- graphs$bng
dg <- graphs$dg

test_node_index <- sample.int(1000, 1)
test_node_name <- paste0("V", test_node_index)
bench::mark(
  caugi = {
    caugi::parents(cg, test_node_name)
    caugi::children(cg, test_node_name)
  },
  igraph = {
    igraph::neighbors(ig, test_node_name, mode = "in")
    igraph::neighbors(ig, test_node_name, mode = "out")
  },
  bnlearn = {
    bnlearn::parents(bng, test_node_name)
    bnlearn::children(bng, test_node_name)
  },
  ggm = {
    ggm::pa(test_node_name, ggmg)
    ggm::ch(test_node_name, ggmg)
  },
  dagitty = {
    dagitty::parents(dg, test_node_name)
    dagitty::children(dg, test_node_name)
  },
  check = FALSE # igraph returns igraph object
)
#> Warning: Some expressions had a GC in every iteration; so filtering is
#> disabled.
#> # A tibble: 5 × 6
#>   expression      min   median `itr/sec` mem_alloc `gc/sec`
#>   <bch:expr> <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
#> 1 caugi       64.77µs  70.88µs 12878.      67.36KB     8.00
#> 2 igraph     532.18µs 569.69µs  1650.     371.34KB     8.00
#> 3 bnlearn     39.82µs   42.6µs 15245.      38.38KB    14.0 
#> 4 ggm         19.04ms  24.58ms    33.1     69.92MB    48.6 
#> 5 dagitty       2.72s    2.72s     0.368    5.09MB     0
```

`bnlearn` is fastest here, but is only able to handle smaller graphs,
whereas `caugi` and `igraph` can handle very large graph objects with
almost no time increase:

``` r
large_cg <- caugi::generate_graph(n = 40000, m = 1000000, class = "DAG")
large_ig <- caugi::as_igraph(large_cg)
test_node_index <- sample.int(40000, 1)
test_node_name <- paste0("V", test_node_index)
bench::mark(
  caugi = {
    caugi::parents(large_cg, test_node_name)
    caugi::children(large_cg, test_node_name)
  },
  igraph = {
    igraph::neighbors(large_ig, test_node_name, mode = "in")
    igraph::neighbors(large_ig, test_node_name, mode = "out")
  },
  check = FALSE
)
#> # A tibble: 2 × 6
#>   expression      min   median `itr/sec` mem_alloc `gc/sec`
#>   <bch:expr> <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
#> 1 caugi        63.3µs   66.6µs    14546.     1008B     8.47
#> 2 igraph      799.1µs  848.1µs     1164.    3.05MB    42.0
```

For ancestors and descendants, we see that `caugi` outperforms all other
packages by a several magnitudes, expect for `igraph`, which it still
beats, but by a smaller margin::

``` r
bench::mark(
  caugi = {
    caugi::ancestors(cg, "V500")
    caugi::descendants(cg, "V500")
  },
  igraph = {
    igraph::subcomponent(ig, "V500", mode = "in")
    igraph::subcomponent(ig, "V500", mode = "out")
  },
  bnlearn = {
    bnlearn::ancestors(bng, "V500")
    bnlearn::descendants(bng, "V500")
  },
  dagitty = {
    dagitty::ancestors(dg, "V500")
    dagitty::descendants(dg, "V500")
  },
  check = FALSE # dagitty returns V500 as well and igraph returns an igraph
)
#> Warning: Some expressions had a GC in every iteration; so filtering is
#> disabled.
#> # A tibble: 4 × 6
#>   expression      min   median `itr/sec` mem_alloc `gc/sec`
#>   <bch:expr> <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
#> 1 caugi      199.98µs 218.89µs  4437.      65.26KB     2.00
#> 2 igraph     640.97µs 717.14µs  1382.     117.85KB     2.00
#> 3 bnlearn       1.15s    1.15s     0.874    1.33GB    13.1 
#> 4 dagitty        2.7s     2.7s     0.370    5.09MB     0
```

#### d-separation

Using the graph from before, we obtain a valid adjustment set and then
check for d-separation.

``` r
valid_adjustment_set <- caugi::adjustment_set(cg, "V500", "V681", type = "backdoor")
valid_adjustment_set
#>   [1] "V7"    "V15"   "V18"   "V24"   "V33"   "V34"   "V68"   "V88"   "V93"  
#>  [10] "V121"  "V134"  "V157"  "V168"  "V197"  "V202"  "V206"  "V213"  "V232" 
#>  [19] "V262"  "V287"  "V290"  "V291"  "V302"  "V306"  "V314"  "V330"  "V332" 
#>  [28] "V342"  "V361"  "V363"  "V368"  "V369"  "V371"  "V385"  "V389"  "V393" 
#>  [37] "V409"  "V416"  "V422"  "V425"  "V429"  "V437"  "V444"  "V457"  "V469" 
#>  [46] "V476"  "V480"  "V493"  "V504"  "V510"  "V514"  "V522"  "V530"  "V543" 
#>  [55] "V555"  "V557"  "V560"  "V564"  "V570"  "V581"  "V588"  "V596"  "V607" 
#>  [64] "V620"  "V621"  "V636"  "V641"  "V652"  "V653"  "V660"  "V664"  "V669" 
#>  [73] "V673"  "V677"  "V697"  "V701"  "V707"  "V735"  "V743"  "V748"  "V768" 
#>  [82] "V785"  "V835"  "V836"  "V844"  "V847"  "V890"  "V893"  "V900"  "V911" 
#>  [91] "V912"  "V923"  "V924"  "V927"  "V943"  "V950"  "V964"  "V966"  "V973" 
#> [100] "V974"  "V989"  "V991"  "V996"  "V1000"
```

``` r
bench::mark(
  caugi = caugi::d_separated(cg, "V500", "V681", valid_adjustment_set),
  bnlearn = bnlearn::dsep(bng, "V500", "V681", valid_adjustment_set),
  dagitty = dagitty::dseparated(dg, "V500", "V681", valid_adjustment_set)
)
#> Warning: Some expressions had a GC in every iteration; so filtering is
#> disabled.
#> # A tibble: 3 × 6
#>   expression      min   median `itr/sec` mem_alloc `gc/sec`
#>   <bch:expr> <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
#> 1 caugi       34.73ms  35.17ms    28.3     33.02KB     0   
#> 2 bnlearn       4.27s    4.27s     0.234    3.22GB     5.15
#> 3 dagitty       2.16s    2.16s     0.463    4.19MB     0
```

#### Subgraph (building)

Here we see an example of where the frontloading hurts performance. When
we build a subgraph, we have to rebuild the entire `caugi` graph object.
Here, we see that while `caugi` outperforms other packages for queries
(except for parents/children for `bnlearn`), it is slower for building
the graph objects themselves, which shows in the subgraph benchmark:

``` r
subgraph_nodes_index <- sample.int(1000, 500)
subgraph_nodes <- paste0("V", subgraph_nodes_index)
bench::mark(
  caugi = {
    caugi::subgraph(cg, subgraph_nodes)
  },
  igraph = {
    igraph::subgraph(ig, subgraph_nodes)
  },
  bnlearn = {
    bnlearn::subgraph(bng, subgraph_nodes)
  },
  check = FALSE
)
#> Warning: Some expressions had a GC in every iteration; so filtering is
#> disabled.
#> # A tibble: 3 × 6
#>   expression      min   median `itr/sec` mem_alloc `gc/sec`
#>   <bch:expr> <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
#> 1 caugi        10.3ms  10.95ms    81.8       8.1MB     1.99
#> 2 igraph       1.92ms   1.97ms   504.       81.1KB     0   
#> 3 bnlearn        1.1s     1.1s     0.908   983.6MB     2.73
```

### Session info

``` r
sessionInfo()
#> R version 4.5.2 (2025-10-31)
#> Platform: x86_64-pc-linux-gnu
#> Running under: Ubuntu 24.04.3 LTS
#> 
#> Matrix products: default
#> BLAS:   /usr/lib/x86_64-linux-gnu/openblas-pthread/libblas.so.3 
#> LAPACK: /usr/lib/x86_64-linux-gnu/openblas-pthread/libopenblasp-r0.3.26.so;  LAPACK version 3.12.0
#> 
#> locale:
#>  [1] LC_CTYPE=C.UTF-8       LC_NUMERIC=C           LC_TIME=C.UTF-8       
#>  [4] LC_COLLATE=C.UTF-8     LC_MONETARY=C.UTF-8    LC_MESSAGES=C.UTF-8   
#>  [7] LC_PAPER=C.UTF-8       LC_NAME=C              LC_ADDRESS=C          
#> [10] LC_TELEPHONE=C         LC_MEASUREMENT=C.UTF-8 LC_IDENTIFICATION=C   
#> 
#> time zone: UTC
#> tzcode source: system (glibc)
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> loaded via a namespace (and not attached):
#>  [1] jsonlite_2.0.0      BiocManager_1.30.26 compiler_4.5.2     
#>  [4] Rcpp_1.1.0          parallel_4.5.2      jquerylib_0.1.4    
#>  [7] systemfonts_1.3.1   textshaping_1.0.4   boot_1.3-32        
#> [10] yaml_2.3.10         fastmap_1.2.0       R6_2.6.1           
#> [13] generics_0.1.4      curl_7.0.0          igraph_2.2.1       
#> [16] knitr_1.50          BiocGenerics_0.56.0 htmlwidgets_1.6.4  
#> [19] MASS_7.3-65         graph_1.88.0        tibble_3.3.0       
#> [22] desc_1.4.3          bslib_0.9.0         pillar_1.11.1      
#> [25] rlang_1.1.6         utf8_1.2.6          V8_8.0.1           
#> [28] cachem_1.1.0        bnlearn_5.1         xfun_0.54          
#> [31] fs_1.6.6            sass_0.4.10         S7_0.2.0           
#> [34] cli_3.6.5           pkgdown_2.2.0       magrittr_2.0.4     
#> [37] digest_0.6.37       lifecycle_1.0.4     dagitty_0.3-4      
#> [40] caugi_0.2.1         vctrs_0.6.5         bench_1.1.4        
#> [43] ggm_2.5.2           evaluate_1.0.5      glue_1.8.0         
#> [46] data.table_1.17.8   ragg_1.5.0          stats4_4.5.2       
#> [49] profmem_0.7.0       rmarkdown_2.30      tools_4.5.2        
#> [52] pkgconfig_2.0.3     htmltools_0.5.8.1
```
