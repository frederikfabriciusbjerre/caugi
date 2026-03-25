library(optparse)
library(caugi)

option_list <- list(
  make_option(c("--output"), type="character", default="pr_time.rds",
              help="RDS file to save benchmark results"),
  make_option(c("--branch-name"), type="character", default="PR branch",
              help="Name of branch for messages")
)
opt <- parse_args(OptionParser(option_list=option_list))

set.seed(1405)
n <- 1000
p <- 0.25

cat(sprintf("Running benchmark on %s...\n", opt$branch_name))

cg <- generate_graph(n, p, class="DAG")
build(cg)

test_node_index <- sample(n, 1)
test_node_name <- paste0("V", test_node_index)
test_node_index_new <- sample(n, 1)
test_node_name_new <- paste0("V", test_node_index_new)

bench_result <- bench::mark(
  parents = parents(cg, test_node_name),
  children = children(cg, test_node_name),
  ancestors = ancestors(cg, test_node_name),
  descendants = descendants(cg, test_node_name),
  subgraph = subgraph(cg, test_node_name),
  d_seperated = {
    valid_adjustment_set <- adjustment_set(cg, test_node_name, test_node_name_new, type="backdoor")
    d_separated(cg, test_node_name, test_node_name_new, valid_adjustment_set)
  },
  check = FALSE
)

saveRDS(bench_result, opt$output)
cat(sprintf("%s benchmark done, results saved to %s\n", opt$branch_name, opt$output))