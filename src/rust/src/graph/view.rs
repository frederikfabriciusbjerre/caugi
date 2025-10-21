use super::admg::Admg;
use super::CaugiGraph;
use super::dag::Dag;
use super::pdag::Pdag;
use std::sync::Arc;

#[derive(Debug, Clone)]
pub enum GraphView {
    Dag(Arc<Dag>),
    Pdag(Arc<Pdag>),
    Admg(Arc<Admg>),
    Raw(Arc<CaugiGraph>),
    // MAG, PAG, etc in the future
}

impl GraphView {
    #[inline]
    pub fn core(&self) -> &CaugiGraph {
        match self {
            GraphView::Dag(d) => d.core_ref(),
            GraphView::Pdag(p) => p.core_ref(),
            GraphView::Admg(a) => a.core_ref(),
            GraphView::Raw(c) => c,
        }
    }

    #[inline]
    pub fn n(&self) -> u32 {
        match self {
            GraphView::Dag(g) => g.n(),
            GraphView::Pdag(g) => g.n(),
            GraphView::Admg(g) => g.n(),
            GraphView::Raw(core) => core.n(),
        }
    }

    // ---- queries ----
    pub fn parents_of(&self, i: u32) -> Result<&[u32], String> {
        match self {
            GraphView::Dag(g) => Ok(g.parents_of(i)),
            GraphView::Pdag(g) => Ok(g.parents_of(i)),
            GraphView::Admg(g) => Ok(g.parents_of(i)),
            GraphView::Raw(_) => Err("parents_of not implemented for UNKNOWN class".into()),
        }
    }
    pub fn children_of(&self, i: u32) -> Result<&[u32], String> {
        match self {
            GraphView::Dag(g) => Ok(g.children_of(i)),
            GraphView::Pdag(g) => Ok(g.children_of(i)),
            GraphView::Admg(g) => Ok(g.children_of(i)),
            GraphView::Raw(_) => Err("children_of not implemented for UNKNOWN class".into()),
        }
    }
    pub fn undirected_of(&self, i: u32) -> Result<&[u32], String> {
        match self {
            GraphView::Dag(_) => Err("undirected_of not defined for Dag".into()),
            GraphView::Pdag(g) => Ok(g.undirected_of(i)),
            GraphView::Admg(_) => Err("undirected_of not defined for Admg".into()),
            GraphView::Raw(_) => Err("undirected_of not implemented for UNKNOWN class".into()),
        }
    }
    pub fn bidirected_of(&self, i: u32) -> Result<&[u32], String> {
        match self {
            GraphView::Dag(_) => Err("bidirected_of not defined for Dag".into()),
            GraphView::Pdag(_) => Err("bidirected_of not defined for Pdag".into()),
            GraphView::Admg(g) => Ok(g.bidirected_of(i)),
            GraphView::Raw(_) => Err("bidirected_of not implemented for UNKNOWN class".into()),
        }
    }
    pub fn neighbors_of(&self, i: u32) -> Result<&[u32], String> {
        match self {
            GraphView::Dag(g) => Ok(g.neighbors_of(i)),
            GraphView::Pdag(g) => Ok(g.neighbors_of(i)),
            GraphView::Admg(g) => Ok(g.neighbors_of(i)),
            GraphView::Raw(_) => Err("neighbors_of not implemented for UNKNOWN class".into()),
        }
    }
    pub fn ancestors_of(&self, i: u32) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(g) => Ok(g.ancestors_of(i)),
            GraphView::Pdag(g) => Ok(g.ancestors_of(i)),
            GraphView::Admg(g) => Ok(g.ancestors_of(i)),
            GraphView::Raw(_) => Err("ancestors_of not implemented for UNKNOWN class".into()),
        }
    }
    pub fn descendants_of(&self, i: u32) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(g) => Ok(g.descendants_of(i)),
            GraphView::Pdag(g) => Ok(g.descendants_of(i)),
            GraphView::Admg(g) => Ok(g.descendants_of(i)),
            GraphView::Raw(_) => Err("descendants_of not implemented for UNKNOWN class".into()),
        }
    }
    pub fn markov_blanket_of(&self, i: u32) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(g) => Ok(g.markov_blanket_of(i)),
            GraphView::Pdag(g) => Ok(g.markov_blanket_of(i)),
            GraphView::Admg(g) => Ok(g.markov_blanket_of(i)),
            GraphView::Raw(_) => Err("markov_blanket_of not implemented for UNKNOWN class".into()),
        }
    }
    pub fn exogenous_nodes(&self, undirected_as_parents: bool) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(g) => Ok(g.exogenous_nodes()),
            GraphView::Pdag(g) => Ok(g.exogenous_nodes(undirected_as_parents)),
            GraphView::Admg(g) => Ok(g.exogenous_nodes()),
            GraphView::Raw(_) => Err("exogenous_nodes not implemented for UNKNOWN class".into()),
        }
    }

    // ---- DAG-only methods ----
    pub fn is_d_separated(&self, xs: &[u32], ys: &[u32], z: &[u32]) -> Result<bool, String> {
        match self {
            GraphView::Dag(d) => Ok(d.is_d_separated(xs, ys, z)),
            _ => Err("is_d_separated is only defined for DAGs".into()),
        }
    }
    pub fn adjustment_set_parents(&self, xs: &[u32], ys: &[u32]) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(d) => Ok(d.adjustment_set_parents(xs, ys)),
            _ => Err("adjustment_set_parents is only defined for DAGs".into()),
        }
    }
    pub fn adjustment_set_backdoor(&self, xs: &[u32], ys: &[u32]) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(d) => Ok(d.adjustment_set_backdoor(xs, ys)),
            _ => Err("adjustment_set_backdoor is only defined for DAGs".into()),
        }
    }
    pub fn adjustment_set_optimal(&self, x: u32, y: u32) -> Result<Vec<u32>, String> {
        match self {
            GraphView::Dag(d) => Ok(d.adjustment_set_optimal(x, y)),
            _ => Err("adjustment_set_optimal is only defined for DAGs".into()),
        }
    }
    pub fn is_valid_backdoor_set(&self, x: u32, y: u32, z: &[u32]) -> Result<bool, String> {
        match self {
            GraphView::Dag(d) => Ok(d.is_valid_backdoor_set(x, y, z)),
            _ => Err("is_valid_backdoor_set is only defined for DAGs".into()),
        }
    }
    pub fn all_backdoor_sets(
        &self,
        x: u32,
        y: u32,
        minimal: bool,
        max_size: u32,
    ) -> Result<Vec<Vec<u32>>, String> {
        match self {
            GraphView::Dag(d) => Ok(d.all_backdoor_sets(x, y, minimal, max_size)),
            _ => Err("all_backdoor_sets is only defined for DAGs".into()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::edges::EdgeRegistry;
    use crate::graph::builder::GraphBuilder;

    #[test]
    fn graphview_dispatch_dag_pdag_raw() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let cdir = r.code_of("-->").unwrap();
        let cund = r.code_of("---").unwrap();

        // DAG core: 0->1, 0->2
        let mut bd = GraphBuilder::new_with_registry(3, true, &r);
        bd.add_edge(0, 1, cdir).unwrap();
        bd.add_edge(0, 2, cdir).unwrap();
        let dag_core = Arc::new(bd.finalize().unwrap());
        let dag = Arc::new(Dag::new(dag_core.clone()).unwrap());
        let v_dag = GraphView::Dag(dag);
        assert_eq!(v_dag.n(), 3);
        assert_eq!(v_dag.parents_of(1).unwrap(), &[0]);
        assert_eq!(v_dag.children_of(0).unwrap(), &[1, 2]);
        assert_eq!(v_dag.neighbors_of(0).unwrap(), &[1, 2]);
        assert_eq!(v_dag.descendants_of(0).unwrap(), vec![1, 2]);
        assert_eq!(v_dag.ancestors_of(2).unwrap(), vec![0]);
        let e = v_dag.undirected_of(0).unwrap_err();
        assert_eq!(e, "undirected_of not defined for Dag");
        let v_dag_core = v_dag.core();
        assert_eq!(v_dag_core.n(), 3);

        // PDAG core: 0->1, 1---2
        let mut bp = GraphBuilder::new_with_registry(4, true, &r);
        bp.add_edge(0, 1, cdir).unwrap();
        bp.add_edge(1, 2, cund).unwrap();
        bp.add_edge(1, 3, cdir).unwrap();
        let pdag_core = Arc::new(bp.finalize().unwrap());
        let pdag = Arc::new(Pdag::new(pdag_core.clone()).unwrap());
        let v_pdag = GraphView::Pdag(pdag);
        assert_eq!(v_pdag.n(), 4);
        assert_eq!(v_pdag.parents_of(1).unwrap(), &[0]);
        assert_eq!(v_pdag.children_of(0).unwrap(), &[1]);
        assert_eq!(v_pdag.undirected_of(1).unwrap(), &[2]);
        assert_eq!(v_pdag.neighbors_of(1).unwrap(), &[0, 2, 3]);
        assert_eq!(v_pdag.descendants_of(0).unwrap(), vec![1, 3]);
        assert_eq!(v_pdag.ancestors_of(3).unwrap(), vec![0, 1]);
        let v_pdag_core = v_pdag.core();
        assert_eq!(v_pdag_core.n(), 4);

        // Raw view uses UNKNOWN class fallbacks
        let v_raw = GraphView::Raw(pdag_core);
        assert_eq!(v_raw.n(), 4);
        let e1 = v_raw.parents_of(0).unwrap_err();
        let e2 = v_raw.children_of(0).unwrap_err();
        let e3 = v_raw.undirected_of(0).unwrap_err();
        assert_eq!(e1, "parents_of not implemented for UNKNOWN class");
        assert_eq!(e2, "children_of not implemented for UNKNOWN class");
        assert_eq!(e3, "undirected_of not implemented for UNKNOWN class");
        assert_eq!(
            v_raw.neighbors_of(0).unwrap_err(),
            "neighbors_of not implemented for UNKNOWN class"
        );

        let v_raw_core = v_raw.core();
        assert_eq!(v_raw_core.n(), 4);
    }

    #[test]
    fn graphview_mb_dispatch() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let mut b = GraphBuilder::new_with_registry(4, true, &r);
        b.add_edge(2, 1, d).unwrap();
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(0, 3, d).unwrap();
        let dag = Arc::new(Dag::new(Arc::new(b.finalize_in_place().unwrap())).unwrap());
        let v = GraphView::Dag(dag);
        assert_eq!(v.markov_blanket_of(0).unwrap(), vec![1, 2, 3]);

        // Pdag:
        let mut b = GraphBuilder::new_with_registry(4, true, &r);
        let u = r.code_of("---").unwrap();
        b.add_edge(2, 1, d).unwrap();
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(0, 3, d).unwrap();
        b.add_edge(1, 3, u).unwrap();
        let pdag = Arc::new(Pdag::new(Arc::new(b.finalize_in_place().unwrap())).unwrap());

        let v = GraphView::Pdag(pdag);
        assert_eq!(v.markov_blanket_of(0).unwrap(), vec![1, 2, 3]);

        // Raw view uses UNKNOWN class fallbacks
        let v = GraphView::Raw(Arc::new(b.finalize().unwrap()));
        assert_eq!(
            v.markov_blanket_of(0).unwrap_err(),
            "markov_blanket_of not implemented for UNKNOWN class"
        );
    }

    #[test]
    fn exogenous_nodes_dag_pdag() {
        use crate::{edges::EdgeRegistry, graph::builder::GraphBuilder};
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let u = r.code_of("---").unwrap();

        // DAG: 0->1, 0->2  => exogenous {0,3}
        let mut b = GraphBuilder::new_with_registry(4, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(0, 2, d).unwrap();
        let v = GraphView::Dag(Arc::new(Dag::new(Arc::new(b.finalize().unwrap())).unwrap()));
        assert_eq!(v.exogenous_nodes(false).unwrap(), vec![0, 3]);

        // PDAG: 0->1, 1--2 => exogenous {0,2,3} if undirected ignored; {0,3} if counted
        let mut b = GraphBuilder::new_with_registry(4, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, u).unwrap();
        let v = GraphView::Pdag(Arc::new(
            Pdag::new(Arc::new(b.finalize().unwrap())).unwrap(),
        ));
        assert_eq!(v.exogenous_nodes(false).unwrap(), vec![0, 2, 3]);
        assert_eq!(v.exogenous_nodes(true).unwrap(), vec![0, 3]);
    }
    #[test]
    fn graphview_dag_adjustment_and_dsep_dispatch() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();

        // DAG: 0:L -> 1:A -> 2:Y and 0:L -> 2:Y (classic confounder)
        let mut b = GraphBuilder::new_with_registry(3, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        b.add_edge(0, 2, d).unwrap();
        let v = GraphView::Dag(Arc::new(Dag::new(Arc::new(b.finalize().unwrap())).unwrap()));

        // d-sep: X=1, Y=2 is not separated unconditionally; conditioning on 0 separates them
        assert_eq!(v.is_d_separated(&[1], &[2], &[]).unwrap(), false);
        assert_eq!(v.is_d_separated(&[0], &[2], &[0]).unwrap(), true);

        // adjustment sets (parents/backdoor/optimal) all return {0}
        assert_eq!(v.adjustment_set_parents(&[1], &[2]).unwrap(), vec![0]);
        assert_eq!(v.adjustment_set_backdoor(&[1], &[2]).unwrap(), vec![0]);
        assert_eq!(v.adjustment_set_optimal(1, 2).unwrap(), vec![0]);

        // backdoor validity + enumeration
        assert_eq!(v.is_valid_backdoor_set(1, 2, &[0]).unwrap(), true);
        assert_eq!(v.is_valid_backdoor_set(1, 2, &[]).unwrap(), false);
        assert_eq!(v.all_backdoor_sets(1, 2, true, 5).unwrap(), vec![vec![0]]);
    }

    // --- d-sep simple chain to hit both true/false via GraphView::Dag ---
    #[test]
    fn graphview_dag_dsep_chain_true_false() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();

        // 0 -> 1 -> 2
        let mut b = GraphBuilder::new_with_registry(3, true, &r);
        b.add_edge(0, 1, d).unwrap();
        b.add_edge(1, 2, d).unwrap();
        let v = GraphView::Dag(Arc::new(Dag::new(Arc::new(b.finalize().unwrap())).unwrap()));

        // Unblocked path 0—1—2 => not separated
        assert_eq!(v.is_d_separated(&[0], &[2], &[]).unwrap(), false);
        // Condition on middle node blocks it
        assert_eq!(v.is_d_separated(&[0], &[2], &[1]).unwrap(), true);
    }

    // --- PDAG and RAW: all DAG-only methods must return errors ---
    #[test]
    fn graphview_pdag_and_raw_dagonly_methods_error() {
        let mut r = EdgeRegistry::new();
        r.register_builtins().unwrap();
        let d = r.code_of("-->").unwrap();
        let u = r.code_of("---").unwrap();

        // Build a small PDAG: 0->1, 1---2
        let mut bp = GraphBuilder::new_with_registry(3, true, &r);
        bp.add_edge(0, 1, d).unwrap();
        bp.add_edge(1, 2, u).unwrap();
        let pdag_core = Arc::new(bp.finalize().unwrap());
        let vp = GraphView::Pdag(Arc::new(Pdag::new(pdag_core.clone()).unwrap()));
        let vr = GraphView::Raw(pdag_core);

        // is_d_separated
        assert_eq!(
            vp.is_d_separated(&[0], &[2], &[]).unwrap_err(),
            "is_d_separated is only defined for DAGs"
        );
        assert_eq!(
            vr.is_d_separated(&[0], &[2], &[]).unwrap_err(),
            "is_d_separated is only defined for DAGs"
        );

        // adjustment_set_parents
        assert_eq!(
            vp.adjustment_set_parents(&[0], &[1]).unwrap_err(),
            "adjustment_set_parents is only defined for DAGs"
        );
        assert_eq!(
            vr.adjustment_set_parents(&[0], &[1]).unwrap_err(),
            "adjustment_set_parents is only defined for DAGs"
        );

        // adjustment_set_backdoor
        assert_eq!(
            vp.adjustment_set_backdoor(&[0], &[1]).unwrap_err(),
            "adjustment_set_backdoor is only defined for DAGs"
        );
        assert_eq!(
            vr.adjustment_set_backdoor(&[0], &[1]).unwrap_err(),
            "adjustment_set_backdoor is only defined for DAGs"
        );

        // adjustment_set_optimal
        assert_eq!(
            vp.adjustment_set_optimal(0, 1).unwrap_err(),
            "adjustment_set_optimal is only defined for DAGs"
        );
        assert_eq!(
            vr.adjustment_set_optimal(0, 1).unwrap_err(),
            "adjustment_set_optimal is only defined for DAGs"
        );

        // is_valid_backdoor_set
        assert_eq!(
            vp.is_valid_backdoor_set(0, 1, &[]).unwrap_err(),
            "is_valid_backdoor_set is only defined for DAGs"
        );
        assert_eq!(
            vr.is_valid_backdoor_set(0, 1, &[]).unwrap_err(),
            "is_valid_backdoor_set is only defined for DAGs"
        );

        // all_backdoor_sets
        assert_eq!(
            vp.all_backdoor_sets(0, 1, true, 5).unwrap_err(),
            "all_backdoor_sets is only defined for DAGs"
        );
        assert_eq!(
            vr.all_backdoor_sets(0, 1, true, 5).unwrap_err(),
            "all_backdoor_sets is only defined for DAGs"
        );
    }
}
