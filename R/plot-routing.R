# Edge routing geometry helpers
#
# These functions are deliberately pure: they operate on plain numeric
# coordinates (in millimeters) with no dependency on grid graphics state, so
# they can be unit tested without an open graphics device. They are used by
# `makeContent.caugi_edge_grob()` (R/plot-grobs.R) at draw time to bend edges
# around non-incident nodes that the straight edge would otherwise cross.

# Distance from a point to a line segment.
#
# Computes the Euclidean distance from point `(px, py)` to the segment
# `(ax, ay)`--`(bx, by)`, together with the clamped projection parameter `t`
# in `[0, 1]` locating the closest point on the segment
# (`(ax, ay) + t * ((bx, by) - (ax, ay))`).
#
# @param px,py Point coordinates.
# @param ax,ay,bx,by Segment endpoint coordinates.
#
# @returns A list with `dist` (numeric distance) and `t` (numeric in `[0, 1]`).
#
# @keywords internal
.point_segment_dist <- function(px, py, ax, ay, bx, by) {
  dx <- bx - ax
  dy <- by - ay
  l2 <- dx * dx + dy * dy

  if (l2 <= 0) {
    # Degenerate (zero-length) segment: distance to the single point.
    t <- 0
    cx <- ax
    cy <- ay
  } else {
    t <- ((px - ax) * dx + (py - ay) * dy) / l2
    t <- max(0, min(1, t))
    cx <- ax + t * dx
    cy <- ay + t * dy
  }

  list(dist = sqrt((px - cx)^2 + (py - cy)^2), t = t)
}

# Compute a routed edge path that avoids obstructing nodes.
#
# Works entirely in millimeters. The curve is built between the two node
# *centers* `(p0x, p0y)` and `(p2x, p2y)` so that, after clipping to the node
# borders, the edge appears to project radially from each center. The straight
# center-to-center segment is tested against a set of obstacle nodes (circle
# centers `(ox, oy)` with radii `or`). If no obstacle is closer than
# `or + clearance`, no routing is needed and the function returns `NULL`.
# Otherwise it builds a cubic Bezier bowed perpendicular to the chord, away
# from the worst-violating obstacle, by enough to clear it. The
# curve is then clipped to each node boundary (trimming the parts within
# `r_from` of `(p0x, p0y)` and within `r_to` of `(p2x, p2y)`) and the surviving
# arc is returned sampled into `n` points.
#
# @param p0x,p0y,p2x,p2y Node *center* coordinates in mm.
# @param r_from,r_to Node radii in mm (used to clip the curve to the borders).
# @param ox,oy Numeric vectors of obstacle center coordinates in mm.
# @param or Numeric vector of obstacle radii in mm.
# @param clearance Extra mm of margin required beyond each obstacle radius.
# @param n Number of points to sample along the clipped curve (default 40).
#
# @returns A list with numeric vectors `x` and `y` of length `n` (the first and
#   last points lying on the respective node borders), or `NULL` when no
#   routing is needed or the curve cannot be fit between the borders.
#
# @keywords internal
route_edge_path <- function(
  p0x,
  p0y,
  p2x,
  p2y,
  r_from,
  r_to,
  ox,
  oy,
  or,
  clearance,
  n = 40L
) {
  n_obs <- length(ox)
  if (n_obs == 0) {
    return(NULL)
  }

  dx <- p2x - p0x
  dy <- p2y - p0y
  seg_len <- sqrt(dx * dx + dy * dy)
  if (seg_len <= 0) {
    return(NULL)
  }

  # Find the worst violator: the obstacle whose required clearance is most
  # exceeded by its proximity to the center-to-center segment.
  worst_k <- 0L
  worst_violation <- 0
  worst_side <- 1
  worst_t <- 0.5

  for (i in seq_len(n_obs)) {
    ps <- .point_segment_dist(ox[i], oy[i], p0x, p0y, p2x, p2y)
    needed <- or[i] + clearance
    violation <- needed - ps$dist
    if (violation > worst_violation) {
      worst_violation <- violation
      worst_k <- i
      worst_t <- ps$t
      # Signed side of the obstacle relative to the directed chord P0->P2
      # (cross product z-component): +1 left, -1 right.
      worst_side <- sign(dx * (oy[i] - p0y) - dy * (ox[i] - p0x))
      if (worst_side == 0) {
        worst_side <- 1
      }
    }
  }

  if (worst_k == 0L) {
    return(NULL)
  }

  # Unit perpendicular to the chord, pointing away from the obstacle.
  bend <- -worst_side
  nperp_x <- bend * -dy / seg_len
  nperp_y <- bend * dx / seg_len

  # Build a cubic Bezier bowed away from the obstacle. Compared with a
  # quadratic, placing the control handles only partway along the chord
  # (`handle_frac`) makes the curve leave each node at a steeper angle, so it
  # reads as projecting from the center and its endpoint marks separate from
  # other edges meeting the same node. `h` is the perpendicular offset of the
  # control points; it is sized so the curve clears the obstacle (whose
  # required perpendicular displacement is `worst_violation`) at its projection
  # `worst_t`, where the cubic reaches `3 * t * (1 - t) * h`.
  handle_frac <- 0.2
  tt <- max(0.15, min(0.85, worst_t))
  h <- (worst_violation + 0.5) / (3 * tt * (1 - tt))
  # Also bow at least a little so short, barely-grazing edges still curve
  # visibly rather than looking kinked.
  h <- max(h, 0.06 * seg_len)

  p1x <- p0x + handle_frac * dx + h * nperp_x
  p1y <- p0y + handle_frac * dy + h * nperp_y
  p2cx <- p0x + (1 - handle_frac) * dx + h * nperp_x
  p2cy <- p0y + (1 - handle_frac) * dy + h * nperp_y

  qx <- function(u) {
    (1 - u)^3 *
      p0x +
      3 * (1 - u)^2 * u * p1x +
      3 * (1 - u) * u^2 * p2cx +
      u^3 * p2x
  }
  qy <- function(u) {
    (1 - u)^3 *
      p0y +
      3 * (1 - u)^2 * u * p1y +
      3 * (1 - u) * u^2 * p2cy +
      u^3 * p2y
  }
  d_from <- function(u) sqrt((qx(u) - p0x)^2 + (qy(u) - p0y)^2)
  d_to <- function(u) sqrt((qx(u) - p2x)^2 + (qy(u) - p2y)^2)

  # If a node is large enough to swallow the whole curve, give up and let the
  # caller fall back to the straight (clipped) edge.
  if (d_from(1) <= r_from || d_to(0) <= r_to) {
    return(NULL)
  }

  # Clip to the node borders by bisection: the distance from each center grows
  # monotonically as we move into the curve, so we can locate the parameter at
  # which the curve crosses each border.
  u_start <- .bisect_u(d_from, r_from, increasing = TRUE)
  u_end <- .bisect_u(d_to, r_to, increasing = FALSE)
  if (u_start >= u_end) {
    return(NULL)
  }

  u <- seq(u_start, u_end, length.out = n)
  list(x = qx(u), y = qy(u))
}

# Locate the curve parameter where a (monotone) distance function crosses a
# target value, via bisection on `[0, 1]`.
#
# When `increasing = TRUE`, `f` grows from 0 at `u = 0`; we return the smallest
# `u` with `f(u) >= target`. When `increasing = FALSE`, `f` grows toward `u = 0`
# (it is 0 at `u = 1`); we return the largest `u` with `f(u) >= target`.
#
# @keywords internal
.bisect_u <- function(f, target, increasing) {
  lo <- 0
  hi <- 1
  for (k in seq_len(40)) {
    mid <- (lo + hi) / 2
    inside <- f(mid) < target
    if (increasing) {
      if (inside) lo <- mid else hi <- mid
    } else {
      if (inside) hi <- mid else lo <- mid
    }
  }
  if (increasing) hi else lo
}
