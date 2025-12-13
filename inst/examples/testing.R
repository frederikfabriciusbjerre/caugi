reg <- edge_registry_new()
edge_registry_register_builtins(reg)
edge_registry_len(reg) # expect 6

# add a new glyph
code <- edge_registry_register(
  reg,
  "--<",
  "line",
  "arrow",
  "left_head",
  "directed",
  FALSE,
  TRUE
)
stopifnot(is.integer(code) || is.double(code)) # u8 wrapped to R scalar
edge_registry_len(reg) # expect 7

# conflict: same glyph, different semantics -> error
try(edge_registry_register(
  reg,
  "-->",
  "line",
  "arrow",
  "right_head",
  "undirected",
  TRUE,
  TRUE
))

# sealing prevents further changes
edge_registry_seal(reg)
try(edge_registry_register(
  reg,
  "o-O",
  "circle",
  "other",
  "right_head",
  "partial",
  FALSE,
  TRUE
))
