---
name: using-dag-draw
description: "Draws directed acyclic graphs in ASCII, SVG, or DOT format using dag-draw.el. Use when asked to visualize DAGs, dependency trees, workflows, state machines, or any directed graph in Emacs."
---

# Drawing DAGs with dag-draw.el

dag-draw.el is an Emacs Lisp library that automatically lays out and renders directed acyclic graphs in ASCII, SVG, or DOT (Graphviz) formats.

## Quick Start

```emacs-lisp
(require 'dag-draw)

(setq g (dag-draw-create-graph))
(dag-draw-add-node g 'a "Step 1")
(dag-draw-add-node g 'b "Step 2")
(dag-draw-add-edge g 'a 'b)
(dag-draw-layout-graph g)
(dag-draw-render-graph g 'ascii)
```

## Creating Graphs

### Imperative API

Build a graph step by step:

```emacs-lisp
(setq g (dag-draw-create-graph))

(dag-draw-add-node g 'start "Start")
(dag-draw-add-node g 'middle "Do Work")
(dag-draw-add-node g 'done "Finish")

(dag-draw-add-edge g 'start 'middle)
(dag-draw-add-edge g 'middle 'done)
```

### Declarative API

Build a graph from a spec — preferred for anything non-trivial:

```emacs-lisp
(setq g (dag-draw-create-from-spec
         :nodes '((start  :label "Start")
                  (middle :label "Do Work")
                  (done   :label "Finish"))
         :edges '((start middle)
                  (middle done))))
```

`dag-draw-create-from-spec` validates the spec eagerly: missing `:label`, duplicate node IDs, and edges referencing nonexistent nodes all signal errors before constructing anything.

## Layout and Rendering

**You must call `dag-draw-layout-graph` before rendering.** It assigns coordinates to nodes and spline points to edges in place.

```emacs-lisp
(dag-draw-layout-graph g)
```

Then render to one of three formats:

```emacs-lisp
(dag-draw-render-graph g 'ascii)   ; ASCII art string
(dag-draw-render-graph g 'svg)     ; SVG string
(dag-draw-render-graph g 'dot)     ; Graphviz DOT string
```

An optional third argument highlights a node (double-line border in ASCII):

```emacs-lisp
(dag-draw-render-graph g 'ascii 'middle)
```

## Node Visual Properties

Nodes accept an optional hash table (requires `ht`) or plist of visual attributes:

### Imperative

```emacs-lisp
(require 'ht)

(dag-draw-add-node g 'done "Research"
  (ht (:ascii-marker "✓ ")))

(dag-draw-add-node g 'active "Implementation"
  (ht (:ascii-highlight t)
      (:ascii-marker "→ ")))

(dag-draw-add-node g 'critical "Fix Bug"
  (ht (:svg-fill "#ff4444")
      (:svg-stroke "#cc0000")
      (:svg-stroke-width 3)))
```

### Declarative

Visual properties go directly in the node spec as keyword arguments:

```emacs-lisp
(dag-draw-create-from-spec
 :nodes '((todo   :label "TODO"        :svg-fill "#e0e0e0")
          (active :label "In Progress" :ascii-highlight t :ascii-marker "→ " :svg-fill "#ffd700")
          (done   :label "Done"        :ascii-marker "✓ " :svg-fill "#90ee90"))
 :edges '((todo active)
          (active done)))
```

### Available Properties

| Property             | Format | Effect                              |
|----------------------|--------|-------------------------------------|
| `:ascii-highlight`   | ASCII  | Double-line border                  |
| `:ascii-marker`      | ASCII  | Prefix string (e.g. `"✓ "`, `"→ "`) |
| `:svg-fill`          | SVG    | Background color                    |
| `:svg-stroke`        | SVG    | Border color                        |
| `:svg-stroke-width`  | SVG    | Border width                        |

## Edge Properties

### Imperative

`dag-draw-add-edge` signature:

```
(dag-draw-add-edge graph from to &optional weight label attributes)
```

```emacs-lisp
(dag-draw-add-edge g 'a 'b)                        ; basic
(dag-draw-add-edge g 'a 'b 10)                     ; weighted (higher = closer)
(dag-draw-add-edge g 'a 'b 1 "optional")           ; labeled
(dag-draw-add-edge g 'a 'b 5 nil (ht ('min-length 2)))  ; min rank gap
```

### Declarative

```emacs-lisp
(dag-draw-create-from-spec
 :nodes '((start    :label "Start")
          (critical :label "Critical Path")
          (optional :label "Optional Step")
          (end      :label "End"))
 :edges '((start critical :weight 10)
          (start optional :weight 1)
          (critical end :weight 10 :label "required")
          (optional end :weight 1)))
```

## Querying the Graph

```emacs-lisp
(dag-draw-get-edges-from g 'hub)       ; outgoing edges from a node
(dag-draw-get-edges-to g 'a)           ; incoming edges to a node
(dag-draw-get-successors g 'root)      ; direct child node IDs
(dag-draw-get-predecessors g 'child)   ; direct parent node IDs
```

## Workflow

1. Create a graph with `dag-draw-create-from-spec` (or `dag-draw-create-graph` + imperative calls).
2. Call `dag-draw-layout-graph` — this is mandatory before rendering.
3. Render with `dag-draw-render-graph` to `'ascii`, `'svg`, or `'dot`.
4. For ASCII output, evaluate the render call and display the resulting string. For SVG, write the string to a `.svg` file.
