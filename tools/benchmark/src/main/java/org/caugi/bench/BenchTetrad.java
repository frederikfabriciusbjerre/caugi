package org.caugi.bench;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.cmu.tetrad.graph.EdgeListGraph;
import edu.cmu.tetrad.graph.Graph;
import edu.cmu.tetrad.graph.GraphNode;
import edu.cmu.tetrad.graph.GraphUtils;
import edu.cmu.tetrad.graph.Node;
import edu.cmu.tetrad.graph.Paths;

import java.io.BufferedReader;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.function.Supplier;

/**
 * Java/Tetrad benchmark runner.
 *
 * Args: <fixturesDir> <outputCsvPath>
 * Reads fixtures/spec.json + fixtures/{id}.edges produced by generate_fixtures.R
 * and writes a long-format CSV mirroring the R/Python runners.
 */
public final class BenchTetrad {

    // Each (operation × fixture) cell runs WARMUP iterations (discarded), then
    // up to MAX_ITERS timed iterations until MIN_TOTAL_NS has elapsed.
    private static final int WARMUP = 3;
    private static final int MIN_ITERS = 5;
    private static final int MAX_ITERS = 10_000;
    private static final long MIN_TOTAL_NS = 50_000_000L; // 0.05s

    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            System.err.println("Usage: BenchTetrad <fixturesDir> <outputCsv>");
            System.exit(2);
        }
        Path fixturesDir = Path.of(args[0]);
        Path outputCsv = Path.of(args[1]);

        ObjectMapper mapper = new ObjectMapper();
        JsonNode spec = mapper.readTree(fixturesDir.resolve("spec.json").toFile());
        JsonNode fixtures = spec.get("fixtures");

        Files.createDirectories(outputCsv.toAbsolutePath().getParent());
        try (PrintWriter w = new PrintWriter(Files.newBufferedWriter(outputCsv))) {
            w.println("language,package,operation,fixture_id,n,p,n_edges,median_ns,min_ns,total_time_ns,n_iter,mem_alloc_bytes");

            for (JsonNode fx : fixtures) {
                String id = fx.get("id").asText();
                int n = fx.get("n").asInt();
                double p = fx.get("p").asDouble();
                int nEdges = fx.get("n_edges").asInt();
                String edgesFile = fx.get("edges_file").asText();

                System.out.printf("[bench_tetrad] %s (n=%d, edges=%d)%n", id, n, nEdges);

                Graph g = buildGraph(fixturesDir.resolve(edgesFile), n);
                String testName = fx.get("test_node").asText();
                Node test = g.getNode(testName);

                List<Node> subNodes = new ArrayList<>();
                for (JsonNode s : fx.get("subgraph_nodes")) {
                    subNodes.add(g.getNode(s.asText()));
                }

                runOp(w, "parents", id, n, p, nEdges,
                        () -> g.getParents(test));
                runOp(w, "children", id, n, p, nEdges,
                        () -> g.getChildren(test));

                final Paths paths = g.paths();
                runOp(w, "ancestors", id, n, p, nEdges,
                        () -> paths.getAncestors(test));
                runOp(w, "descendants", id, n, p, nEdges,
                        () -> paths.getDescendants(test));

                runOp(w, "markov_blanket", id, n, p, nEdges,
                        () -> GraphUtils.markovBlanket(test, g));

                runOp(w, "subgraph", id, n, p, nEdges,
                        () -> g.subgraph(subNodes));

                JsonNode dsep = fx.get("dsep");
                if (dsep != null && !dsep.isNull()) {
                    Node x = g.getNode(dsep.get("x").asText());
                    Node y = g.getNode(dsep.get("y").asText());
                    Set<Node> z = new HashSet<>();
                    for (JsonNode zn : dsep.get("z")) {
                        z.add(g.getNode(zn.asText()));
                    }
                    runOp(w, "d_separated", id, n, p, nEdges,
                            () -> paths.isMSeparatedFrom(x, y, z, false));
                }
            }
        }
        System.out.println("[bench_tetrad] wrote " + outputCsv);
    }

    private static Graph buildGraph(Path edgesPath, int n) throws Exception {
        List<Node> nodes = new ArrayList<>(n);
        for (int i = 1; i <= n; i++) {
            nodes.add(new GraphNode("V" + i));
        }
        Graph g = new EdgeListGraph(nodes);
        try (BufferedReader r = Files.newBufferedReader(edgesPath)) {
            String line;
            while ((line = r.readLine()) != null) {
                if (line.isEmpty()) continue;
                String[] parts = line.split("\t", 2);
                Node from = g.getNode(parts[0]);
                Node to = g.getNode(parts[1]);
                g.addDirectedEdge(from, to);
            }
        }
        return g;
    }

    private static void runOp(PrintWriter w, String operation, String id,
                              int n, double p, int nEdges,
                              Supplier<Object> fn) {
        // warmup
        for (int i = 0; i < WARMUP; i++) {
            blackhole(fn.get());
        }

        long[] samples = new long[MAX_ITERS];
        int count = 0;
        long startTotal = System.nanoTime();
        while (count < MAX_ITERS) {
            long t0 = System.nanoTime();
            Object r = fn.get();
            long t1 = System.nanoTime();
            blackhole(r);
            samples[count++] = t1 - t0;
            if (count >= MIN_ITERS && (System.nanoTime() - startTotal) >= MIN_TOTAL_NS) {
                break;
            }
        }
        long[] timed = Arrays.copyOf(samples, count);
        Arrays.sort(timed);
        long median = timed[timed.length / 2];
        long min = timed[0];
        long total = 0L;
        for (long s : timed) total += s;

        w.printf("Java,tetrad,%s,%s,%d,%s,%d,%d,%d,%d,%d,%n",
                operation, id, n, formatDouble(p), nEdges,
                median, min, total, count);
    }

    private static String formatDouble(double d) {
        // Avoid scientific notation for small values; CSV-safe.
        if (d == (long) d) return Long.toString((long) d);
        return Double.toString(d);
    }

    // Volatile sink to discourage JIT from eliminating the operation results.
    private static volatile Object SINK;

    private static void blackhole(Object o) {
        SINK = o;
    }
}
