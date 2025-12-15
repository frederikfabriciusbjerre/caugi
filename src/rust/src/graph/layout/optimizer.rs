// SPDX-License-Identifier: MIT
//! Conjugate gradient optimization algorithm.
//!
//! This module provides a general-purpose conjugate gradient optimizer
//! that can be used by various layout algorithms.

/// Conjugate gradient optimization using Fletcher-Reeves formula.
///
/// Minimizes an objective function by iteratively updating positions
/// based on gradient information and conjugate search directions.
///
/// # Arguments
/// * `positions` - Mutable slice of position values to optimize (modified in-place)
/// * `compute_gradient` - Function that computes gradient at current positions
/// * `compute_objective` - Function that computes objective value at current positions
/// * `max_iter` - Maximum number of iterations
/// * `tolerance` - Convergence tolerance for gradient norm
pub fn conjugate_gradient_optimize<F, G>(
    positions: &mut [f64],
    mut compute_gradient: F,
    compute_objective: G,
    max_iter: usize,
    tolerance: f64,
) where
    F: FnMut(&[f64], &mut [f64]),
    G: Fn(&[f64]) -> f64,
{
    let dim = positions.len();
    let mut gradient = vec![0.0; dim];
    let mut direction = vec![0.0; dim];
    let mut old_gradient = vec![0.0; dim];

    // Initial gradient
    compute_gradient(positions, &mut gradient);

    // Initial direction = -gradient
    for i in 0..dim {
        direction[i] = -gradient[i];
    }

    for iter in 0..max_iter {
        // Check convergence
        let grad_norm: f64 = gradient.iter().map(|&g| g * g).sum::<f64>().sqrt();
        if grad_norm < tolerance {
            break;
        }

        // Line search to find step size
        let alpha = line_search(positions, &direction, &compute_objective);

        // Update positions
        for i in 0..dim {
            positions[i] += alpha * direction[i];
        }

        // Store old gradient
        old_gradient.copy_from_slice(&gradient);

        // Compute new gradient
        compute_gradient(positions, &mut gradient);

        // Fletcher-Reeves formula for beta
        let numerator: f64 = gradient.iter().map(|&g| g * g).sum();
        let denominator: f64 = old_gradient.iter().map(|&g| g * g).sum();
        let beta = if denominator > 1e-10 {
            numerator / denominator
        } else {
            0.0
        };

        // Update search direction
        for i in 0..dim {
            direction[i] = -gradient[i] + beta * direction[i];
        }

        // Restart CG periodically to avoid numerical issues
        let restart_period = (dim as f64).sqrt().ceil() as usize;
        if iter % restart_period == 0 && iter > 0 {
            for i in 0..dim {
                direction[i] = -gradient[i];
            }
        }
    }
}

/// Simple backtracking line search.
///
/// Finds a step size that reduces the objective function using
/// the Armijo condition with backtracking.
fn line_search<F>(positions: &[f64], direction: &[f64], compute_objective: F) -> f64
where
    F: Fn(&[f64]) -> f64,
{
    let mut alpha = 1.0;
    let tau = 0.5; // reduction factor

    let f0 = compute_objective(positions);

    let mut test_positions = positions.to_vec();

    for _ in 0..20 {
        // Test positions with current alpha
        for i in 0..positions.len() {
            test_positions[i] = positions[i] + alpha * direction[i];
        }

        let f_new = compute_objective(&test_positions);

        // Armijo condition: accept if objective decreased
        if f_new < f0 {
            return alpha;
        }

        alpha *= tau;
    }

    alpha
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_quadratic_optimization() {
        // Minimize f(x, y) = (x - 3)^2 + (y + 2)^2
        // Minimum at (3, -2)

        let mut positions = vec![0.0, 0.0]; // Start at origin

        let compute_gradient = |pos: &[f64], grad: &mut [f64]| {
            grad[0] = 2.0 * (pos[0] - 3.0);
            grad[1] = 2.0 * (pos[1] + 2.0);
        };

        let compute_objective = |pos: &[f64]| {
            let dx = pos[0] - 3.0;
            let dy = pos[1] + 2.0;
            dx * dx + dy * dy
        };

        conjugate_gradient_optimize(
            &mut positions,
            compute_gradient,
            compute_objective,
            100,
            1e-6,
        );

        // Should converge to (3, -2)
        assert!((positions[0] - 3.0).abs() < 0.01);
        assert!((positions[1] + 2.0).abs() < 0.01);
    }

    #[test]
    fn test_rosenbrock_optimization() {
        // Minimize Rosenbrock function: f(x,y) = (1-x)^2 + 100(y-x^2)^2
        // Minimum at (1, 1)

        let mut positions = vec![0.0, 0.0];

        let compute_gradient = |pos: &[f64], grad: &mut [f64]| {
            let x = pos[0];
            let y = pos[1];
            grad[0] = -2.0 * (1.0 - x) + 200.0 * (y - x * x) * (-2.0 * x);
            grad[1] = 200.0 * (y - x * x);
        };

        let compute_objective = |pos: &[f64]| {
            let x = pos[0];
            let y = pos[1];
            let a = 1.0 - x;
            let b = y - x * x;
            a * a + 100.0 * b * b
        };

        conjugate_gradient_optimize(
            &mut positions,
            compute_gradient,
            compute_objective,
            1000,
            1e-4,
        );

        // Should converge close to (1, 1) (Rosenbrock is notoriously difficult)
        assert!((positions[0] - 1.0).abs() < 0.1);
        assert!((positions[1] - 1.0).abs() < 0.1);
    }
}
