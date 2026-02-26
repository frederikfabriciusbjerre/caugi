test_that("caugi_options retrieves all options when called without arguments", {
  opts <- caugi_options()
  expect_type(opts, "list")
  expect_true("plot" %in% names(opts))
})

test_that("caugi_options retrieves top-level option", {
  plot_opts <- caugi_options("plot")
  expect_type(plot_opts, "list")
  expect_true("node_style" %in% names(plot_opts))
  expect_true("edge_style" %in% names(plot_opts))
  expect_true("tier_style" %in% names(plot_opts))
})

test_that("caugi_options drills down through nested options", {
  # Two levels deep
  tier_style <- caugi_options("plot", "tier_style")
  expect_type(tier_style, "list")
  expect_true("boxes" %in% names(tier_style))
  expect_true("fill" %in% names(tier_style))

  # Three levels deep
  fill <- caugi_options("plot", "node_style", "fill")
  expect_type(fill, "character")
  expect_equal(fill, "lightgrey")

  padding <- caugi_options("plot", "node_style", "padding")
  expect_type(padding, "double")
  expect_equal(padding, 2)
})

test_that("caugi_options errors for non-existent nested keys", {
  expect_error(
    caugi_options("plot", "nonexistent"),
    "Option 'plot\\$nonexistent' does not exist"
  )

  expect_error(
    caugi_options("nonexistent"),
    "Option 'nonexistent' does not exist"
  )

  expect_error(
    caugi_options("plot", "node_style", "nonexistent"),
    "Option 'plot\\$node_style\\$nonexistent' does not exist"
  )
})

test_that("caugi_options errors when drilling into non-list values", {
  expect_error(
    caugi_options("plot", "node_style", "fill", "something"),
    "Cannot access 'plot\\$node_style\\$fill\\$something': 'plot\\$node_style\\$fill' is not a list"
  )

  expect_error(
    caugi_options("plot", "node_style", "padding", "something"),
    "Cannot access 'plot\\$node_style\\$padding\\$something': 'plot\\$node_style\\$padding' is not a list"
  )
})

test_that("caugi_options sets options and returns old values", {
  # Save original
  original <- caugi_options("plot")

  # Set new value
  old_val <- caugi_options(plot = list(node_style = list(fill = "blue")))
  expect_equal(old_val$plot$node_style$fill, "lightgrey")

  # Verify new value is set
  expect_equal(caugi_options("plot", "node_style", "fill"), "blue")

  # Restore original
  caugi_options(plot = original)
  expect_equal(caugi_options("plot", "node_style", "fill"), "lightgrey")
})

test_that("caugi_options preserves other nested values when setting", {
  original <- caugi_options("plot")

  # Set only fill, other node_style properties should be preserved
  caugi_options(plot = list(node_style = list(fill = "red")))

  expect_equal(caugi_options("plot", "node_style", "fill"), "red")
  expect_equal(caugi_options("plot", "node_style", "padding"), 2)
  expect_equal(caugi_options("plot", "node_style", "size"), 1)

  # Restore
  caugi_options(plot = original)
})

test_that("caugi_default_options returns expected structure", {
  defaults <- caugi_default_options()
  expect_type(defaults, "list")
  expect_true("plot" %in% names(defaults))
  expect_true("tier_style" %in% names(defaults$plot))
  expect_equal(defaults$plot$node_style$fill, "lightgrey")
})

test_that("caugi_options handles empty list values", {
  # Empty lists are valid option values (e.g., label_style)
  label_style <- caugi_options("plot", "label_style")
  expect_type(label_style, "list")
  expect_equal(length(label_style), 0)
})

test_that("caugi_options retrieves grid::unit values", {
  # Some options use grid::unit (spacing, tier_style$padding)
  spacing <- caugi_options("plot", "spacing")
  expect_s3_class(spacing, "unit")

  tier_padding <- caugi_options("plot", "tier_style", "padding")
  expect_s3_class(tier_padding, "unit")
})

test_that("caugi_options resets to defaults", {
  # Modify options
  caugi_options(plot = list(node_style = list(fill = "blue")))
  expect_equal(caugi_options("plot", "node_style", "fill"), "blue")

  # Reset to defaults
  caugi_options(caugi_default_options())
  expect_equal(caugi_options("plot", "node_style", "fill"), "lightgrey")
})

test_that("caugi_options sets multiple options at once", {
  original <- caugi_options("plot")

  # Set multiple nested options simultaneously
  caugi_options(
    plot = list(
      spacing = grid::unit(2, "lines"),
      node_style = list(fill = "red", padding = 5),
      edge_style = list(arrow_size = 6)
    )
  )

  expect_equal(as.numeric(caugi_options("plot", "spacing")), 2)
  expect_equal(caugi_options("plot", "node_style", "fill"), "red")
  expect_equal(caugi_options("plot", "node_style", "padding"), 5)
  expect_equal(caugi_options("plot", "edge_style", "arrow_size"), 6)

  # Other options should be preserved
  expect_equal(caugi_options("plot", "node_style", "size"), 1)

  # Restore
  caugi_options(plot = original)
})
