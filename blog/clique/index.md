---
title: Part of the Clique
date: 2026-03-03 11:38:00
description: Discovering the Clique library to draw graphs in Lustre
slug: part-of-the-clique
---

[Clique](https://github.com/hayleigh-dot-dev/clique) is a graph component library for Lustre. Since I'm working on a *really cool project* that involves graphs and trees in Lustre, I might as well use this. One can only re-invent the wheel so many times!

## Reading the Demo

Currently, Clique is not published but is available as a git dependency. It also lacks any kind of documentation, but does have a demo, so let's read through it.


### The Demo Model

Since Clique is a library of components, we first need a proper Lustre application. The demo uses the following model type:

```gleam
import clique/bounds.{type Bounds}
import clique/transform.{type Transform}
import clique/handle.{type Handle, Handle}

type Model {
  Model(
    nodes: List(Node),
    edges: List(Edge),
    viewport: Bounds,
    transform: Transform,
  )
}

type Node {
  Node(id: String, x: Float, y: Float, label: String)
}

type Edge {
  Edge(id: String, source: Handle, target: Handle)
}
```

We can see that the `Node` and `Edge` types are custom, while the `Bounds` and `Transform` types are imported from Clique.

### Node

Looking at the `init` function:
```gleam
    Node(
        id: "node-" <> int.to_string(i),
        x: int.to_float({ i % columns } * 100),
        y: int.to_float({ i / columns } * 100),
        label: "Node " <> int.to_string(i),
    )
```

We see that the `id` of a node is going to be `"node-X"` where X is its index. I wonder if that's going to be useful later :^).

`x` and `y` seem to be maybe a pixel position? That would make sense if each column and each row is 100 pixels wide.

If we have 3 columns for instance, node #5 would be on `x = 5 % 3 = 2` and `y = 5 / 3 = 1`, so `x = 2` and `y = 1`, so `x = 200` and `y = 100`. Sure looks like pixel positions to me!

### Bounds

Looking at the `Model` definition, `Bounds` is actually called `viewport`. We can infer that the `Bounds` are going to be the area within which the graph will be drawn.

### Transform

What's a `Transform` though? Looking at the Clique source:
```gleam
///
///
/// Note: for performance reasons, the `Transform` type is a tuple rather than a
/// record. The fields are as follows:
///
/// - 0: x
/// - 1: y
/// - 2: zoom
///
/// Prefer using the [`new`](#new) function for constructing `Transform` values
/// and the [`x`](#x), [`y`](#y), and [`zoom`](#zoom) functions for accessing
/// them.
///
pub type Transform =
  #(Float, Float, Float)
```

We quickly understand without digging too deep that `Transform` in essence controls the "camera" that will "look" at the graph to be drawn onto our viewport.

If you're not familiar, "transform" is a mathematical term that's used when applying an operation to all values of a set. For instance, on a 2D plane, a "rotation" is a transform, "stretching" is a transform, "flipping" is a transform.

### Handle

While the `Node` type is pretty straight forward, the `Edge` type is a little strange. You'd think the `source` and `target` would be `Node`s, but instead they're using Clique's `Handle` type. What's that?

Again looking at the Clique sources:

```gleam
pub type Handle {
  Handle(node: String, name: String)
}
```

Ok well that doesn't help. A first guess would be that, maybe within Clique a `node` is identified by a unique `String`, and `name` is just a label?

In fact it seems that `handle.gleam` is registering its own Lustre component, with its own Model and everything. Is that really necessary? What's the point?

Well I'm not sure, but now coming back to the Demo Lustre app, we can make sense of how we initialize our `Edge`s in the `init` function:

```gleam
      Edge(
        id: "edge-"
          <> int.to_string(source_index)
          <> "-"
          <> int.to_string(target_index),
        source: Handle("node-" <> int.to_string(source_index), "output"),
        target: Handle("node-" <> int.to_string(target_index), "input"),
      )
```

... With each `Node` getting its own index. So `Handle`s seem to maybe bind to elements based on their IDs perhaps? Maybe we'll see some `div`s with `attribute.id("node-X")`.

Hopefully the view will yield some answers.

## View

Skipping over some of the initial attributes provided by Clique, like `clique.initial_transform`, `clique.on_resize`, `clique.on_connection_cancel` (which seem to be custom Clique events to manage the viewport and transform and stuff), we see some interesting elements within our root div:
- `clique.background`
- `clique.nodes`
- `clique.edges`

These 3 functions aren't actually that interesting. `clique.nodes` and `clique.edges` specifically don't actually do much, they only create keyed fragment elements for each tuple `#(String, Element(msg))`, where the `String` is actually the (unique) fragment key.

The interesting part is in how we create the Tuples

### Node View Tuple

```gleam
use Node(id:, ..) as data <- list.map(model.nodes)
let key = id
let html = view_node(data, on_drag: UserDraggedNode)

#(key, html)
```

Ok so for each `Node`, we're rendering it with the `view_node` function and key-ing it... what's `view_node` look like?

```gleam
fn view_node(
  data: Node,
  on_drag handle_drag: fn(String, Float, Float) -> msg,
) -> Element(msg) {
  let attributes = [
    node.position(data.x, data.y),
    node.on_drag(fn(id, x, y, _, _) { handle_drag(id, x, y) }),
  ]

  clique.node(data.id, attributes, [
    html.div([], [
      clique.handle("input", []),
      html.text(data.label),
      clique.handle("output", []),
    ]),
  ])
}
```

(I've cut out tailwind classes for clarity)

Each node element is created by:
- setting its position with `node.position`, which returns some attributes (don't care to go deeper than that, likely have to do with positioning the node, duh)
- adding some events for dragging the node with `node.on_drag`
- create the `node` element with `clique.node`
    - within that created node, create some children elements for the `handle`s, likely those used by the edges I guess?

Looking at the `node` function within `clique.gleam`:
```gleam
pub fn node(
  id: String,
  attributes: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  node.root([attribute.id(id), ..attributes], children)
}
```

**DING DING DING** I was right on the money. See this *beautiful* `attribute.id(id)`?

So my guess is when the `Edge`s are drawn, they look for the `Node` element with id `node-X` and then fetch the `handle` element that's either `input` or `output`.

### Edge View Tuple

For the sake of completion, let's also look at how `Edge`s are drawn:
```gleam
fn view_edge(data: Edge) -> Element(msg) {
  clique.edge(data.source, data.target, [edge.linear()], [
    html.p([], [
      html.text(data.source.node <> " → " <> data.target.node),
    ]),
  ])
}
```

This is the part I'm excited for, the `edge.linear()`. It returns an `attribute` that, I'm guessing, will make the edge a straight line. So that's how you get different edges/arrows to look different? Good, I'll definitely need that.

## Putting it all together

Ok so trying to summarize everything we've seen. To use Clique we must:
- Define our Model
- Define our own `Node` structure
- Each `Node` must have a unique `String` id
- Each node must have any number of `Handle`s that `Edge`s will bind to
- Define `Bounds` (viewport)
- Define a `Transform` (camera)
- Draw the graph
- Use `clique.root` for the viewport
- Use `clique.background` to set the... background
- Use `clique.nodes` to create keyed elements (not strictly necessary, just better performance)
- Create each node element with `clique.node`, giving it a unique ID AND including the `Handle`s as children with `clique.handle`
- Use `clique.edges` to create keyed elements (not strictly necessary)
- Create each edge element with `clique.edge`, defining how to draw the edge with (for instance) `edge.linear()`

## And yet, we're not even close to done

I haven't even *looked* at the `update` function. My assumption is that for now this would work for a very boring static graph, and I can add interactivity as I move forward.