// SPDX-License-Identifier: MIT
//! Coordinate normalization and rotation utilities for graph layouts.

/// Normalize coordinates to [0, 1] box.
/// The largest dimension is scaled to [0, 1], maintaining aspect ratio.
pub fn normalize_to_unit_box(coords: &mut [(f64, f64)]) {
    if coords.is_empty() {
        return;
    }

    // Find bounding box
    let mut min_x = f64::INFINITY;
    let mut max_x = f64::NEG_INFINITY;
    let mut min_y = f64::INFINITY;
    let mut max_y = f64::NEG_INFINITY;

    for &(x, y) in coords.iter() {
        min_x = min_x.min(x);
        max_x = max_x.max(x);
        min_y = min_y.min(y);
        max_y = max_y.max(y);
    }

    let width = max_x - min_x;
    let height = max_y - min_y;

    // Scale by the largest dimension
    let scale = width.max(height);

    if scale < 1e-10 {
        // All points are at the same location
        for coord in coords.iter_mut() {
            *coord = (0.5, 0.5);
        }
        return;
    }

    // Translate and scale
    for coord in coords.iter_mut() {
        coord.0 = (coord.0 - min_x) / scale;
        coord.1 = (coord.1 - min_y) / scale;
    }
}

/// Rotate coordinates to align with principal components.
/// The first principal component is aligned with the x-axis using PCA.
pub fn rotate_to_principal_axes(coords: &mut [(f64, f64)]) {
    let n = coords.len();
    if n < 2 {
        return;
    }

    // Compute centroid
    let (cx, cy) = coords
        .iter()
        .fold((0.0, 0.0), |(sx, sy), &(x, y)| (sx + x, sy + y));
    let cx = cx / n as f64;
    let cy = cy / n as f64;

    // Center the coordinates
    let centered: Vec<(f64, f64)> = coords.iter().map(|&(x, y)| (x - cx, y - cy)).collect();

    // Compute covariance matrix
    let mut cov_xx = 0.0;
    let mut cov_xy = 0.0;
    let mut cov_yy = 0.0;

    for &(x, y) in &centered {
        cov_xx += x * x;
        cov_xy += x * y;
        cov_yy += y * y;
    }

    cov_xx /= n as f64;
    cov_xy /= n as f64;
    cov_yy /= n as f64;

    // Compute eigenvector for first principal component
    // For 2x2 symmetric matrix, we can compute this analytically
    let trace = cov_xx + cov_yy;
    let det = cov_xx * cov_yy - cov_xy * cov_xy;
    let lambda1 = trace / 2.0 + ((trace * trace / 4.0 - det).max(0.0)).sqrt();

    // Eigenvector corresponding to lambda1
    let (v1x, v1y) = if cov_xy.abs() > 1e-10 {
        let vx = lambda1 - cov_yy;
        let vy = cov_xy;
        let norm = (vx * vx + vy * vy).sqrt();
        (vx / norm, vy / norm)
    } else if cov_xx > cov_yy {
        (1.0, 0.0)
    } else {
        (0.0, 1.0)
    };

    // Rotate coordinates to align first PC with x-axis
    for (i, &(x, y)) in centered.iter().enumerate() {
        let x_rot = v1x * x + v1y * y;
        let y_rot = -v1y * x + v1x * y;
        coords[i] = (x_rot, y_rot);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_normalize_to_unit_box() {
        let mut coords = vec![(0.0, 0.0), (100.0, 50.0), (50.0, 100.0)];
        normalize_to_unit_box(&mut coords);

        // Largest dimension is 100, so scale by 100
        // All coordinates should be in [0, 1]
        for &(x, y) in &coords {
            assert!(x >= 0.0 && x <= 1.0);
            assert!(y >= 0.0 && y <= 1.0);
        }

        // Check that the maximum coordinate is 1.0
        let max_coord = coords.iter().map(|&(x, y)| x.max(y)).fold(0.0, f64::max);
        assert!((max_coord - 1.0).abs() < 1e-10);
    }

    #[test]
    fn test_normalize_empty() {
        let mut coords: Vec<(f64, f64)> = vec![];
        normalize_to_unit_box(&mut coords);
        assert!(coords.is_empty());
    }

    #[test]
    fn test_normalize_single_point() {
        let mut coords = vec![(5.0, 10.0)];
        normalize_to_unit_box(&mut coords);
        // Single point should be centered
        assert!((coords[0].0 - 0.5).abs() < 1e-10);
        assert!((coords[0].1 - 0.5).abs() < 1e-10);
    }

    #[test]
    fn test_rotate_to_principal_axes() {
        // Create points along a diagonal line
        let mut coords = vec![(0.0, 0.0), (1.0, 1.0), (2.0, 2.0), (3.0, 3.0)];
        rotate_to_principal_axes(&mut coords);

        // After rotation, points should be aligned along one axis
        // All y-coordinates should be close to 0 (or all x-coordinates close to 0)
        let y_values: Vec<f64> = coords.iter().map(|&(_, y)| y.abs()).collect();
        let max_y = y_values.iter().fold(0.0_f64, |a, &b| a.max(b));

        // Y values should be small after rotation to principal axis
        assert!(max_y < 0.1);
    }

    #[test]
    fn test_rotate_single_point() {
        let mut coords = vec![(5.0, 10.0)];
        rotate_to_principal_axes(&mut coords);
        // Single point rotation should be a no-op
        assert!(coords.len() == 1);
    }

    #[test]
    fn test_normalize_preserves_aspect_ratio_direction() {
        // Wide rectangle
        let mut coords = vec![(0.0, 0.0), (200.0, 0.0), (200.0, 100.0), (0.0, 100.0)];
        normalize_to_unit_box(&mut coords);

        // Width should be 1.0, height should be 0.5
        let width = coords.iter().map(|&(x, _)| x).fold(0.0, f64::max);
        let height = coords.iter().map(|&(_, y)| y).fold(0.0, f64::max);

        assert!((width - 1.0).abs() < 1e-10);
        assert!((height - 0.5).abs() < 1e-10);
    }

    #[test]
    fn test_rotate_already_aligned_horizontal() {
        // Points already aligned horizontally (cov_xy ≈ 0, cov_xx > cov_yy)
        let mut coords = vec![(0.0, 0.0), (1.0, 0.0), (2.0, 0.0), (3.0, 0.0)];
        rotate_to_principal_axes(&mut coords);

        // Should remain horizontal (or become horizontal if slightly off)
        // All y-coordinates should be very close to 0
        for &(_, y) in &coords {
            assert!(y.abs() < 1e-6, "y={} should be near 0", y);
        }
    }

    #[test]
    fn test_rotate_already_aligned_vertical() {
        // Points already aligned vertically (cov_xy ≈ 0, cov_yy > cov_xx)
        let mut coords = vec![(0.0, 0.0), (0.0, 1.0), (0.0, 2.0), (0.0, 3.0)];
        rotate_to_principal_axes(&mut coords);

        // After rotation, the principal axis (vertical) should be aligned to x-axis
        // So all y-coordinates should be very close to 0
        for &(_, y) in &coords {
            assert!(y.abs() < 1e-6, "y={} should be near 0", y);
        }
    }

    #[test]
    fn test_rotate_equal_variance() {
        // Points in a circle (equal variance in x and y)
        let mut coords = vec![(1.0, 0.0), (0.0, 1.0), (-1.0, 0.0), (0.0, -1.0)];
        rotate_to_principal_axes(&mut coords);

        // Should still form a circle (rotation doesn't change shape)
        // All points should be at same distance from origin
        let distances: Vec<f64> = coords
            .iter()
            .map(|&(x, y)| (x * x + y * y).sqrt())
            .collect();

        let avg_dist = distances.iter().sum::<f64>() / distances.len() as f64;
        for &dist in &distances {
            assert!((dist - avg_dist).abs() < 0.1, "Distance variance too high");
        }
    }

    #[test]
    fn test_normalize_all_points_same() {
        // All points at the same location (scale < 1e-10)
        let mut coords = vec![(5.0, 10.0), (5.0, 10.0), (5.0, 10.0)];
        normalize_to_unit_box(&mut coords);

        // All should be centered at (0.5, 0.5)
        for &(x, y) in &coords {
            assert!((x - 0.5).abs() < 1e-10);
            assert!((y - 0.5).abs() < 1e-10);
        }
    }
}
