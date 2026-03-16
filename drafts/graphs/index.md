---
title: Learn Graph Theory
date: 2026-03-07 13:00:00
description: Let's draw some happy little graphs
slug: learn-graph-theory
---

Definitions:
    - "incidence": "An edge is "Incident" to vertices u and v if it is connected to u and v.
    - "adjacence": two vertices are adjacent if they have an edge connecting them. Also called "neighbors"
    - "degree of a vertex": the number of edges incident to the vertex -> "Handshaking-Lemma: sum of all degrees of a graph = 2*number of edges" -> Amount of odd-degree vertices is even
    - path: between two vertices, has a length in amount of edges traversed.
    - "reachable": A u-v-path means u is reachable from v and vice versa
    - cycle: u-u-path is a cycle
    - "connected": A graph is "connected" is there is a u-v-path for every pair of vertices (u, v)
    - "subgraph": subset of nodes and edges. The edges of a subgraph must only be incident to vertices within the subgraph
    - "induced subgraph": Pick the vertices, then include all the edges that interconnect them present in the parent graph
    - "connected components": Set of subgraphs that are each "connected". If the parent graph is already connected, then the "connected component" is the parent graph itself. They're basically graph islands.