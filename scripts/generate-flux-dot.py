import sys
import yaml
import argparse
from collections import defaultdict

"""
Flux Kustomization Dependency Graph Generator

This script generates dependency graphs for Flux Kustomizations from a Kubernetes YAML file.
It can create both ASCII tree visualizations and Graphviz DOT files for visualization.

Usage:
    # Show complete dependency tree:
    kubectl get ks -A -o yaml | python3 flux_dep_graph.py

    # Show dependencies for specific target:
    kubectl get ks -A -o yaml | python3 flux_dep_graph.py --target <kustomization-name>

    # Generate visual graph from DOT file:
    dot -Tpng dependencies.dot -o dependencies.png

The script will:
1. Generate an ASCII tree showing dependencies
2. Create a dependencies.dot file for Graphviz visualization
3. Color-code the relationships in the DOT graph:
   - Target node: Yellow
   - Upstream dependencies: Light Blue
   - Downstream dependents: Light Green
   - Both upstream/downstream: Orange
   - Direct connections to target: Red edges

Generated with assistance from aider.chat using claude-3-5-sonnet-20241022 in architect mode
Tokens: 4.9k sent, 842 received. Cost: $0.03 message, $0.49 session.
"""

def build_graph(items):
    """
    Build forward and reverse dependency graphs from Kubernetes items.

    Args:
        items: List of Kubernetes resource dictionaries

    Returns:
        tuple: (
            dependencies: dict of node -> list of dependencies,
            reverse_deps: dict of node -> list of dependents,
            meta_info: dict of node -> namespace,
            roots: list of nodes with no dependencies
        )
    """
    # Build forward and reverse dependency graphs
    dependencies = defaultdict(list)   # name -> list of dependencies
    reverse_deps = defaultdict(list)   # name -> who depends on me
    meta_info = {}                     # name -> namespace (optional, for clarity)

    for item in items:
        kind = item.get("kind")
        if kind != "Kustomization":
            continue
        metadata = item.get("metadata", {})
        spec = item.get("spec", {})
        name = metadata.get("name")
        namespace = metadata.get("namespace", "flux-system")
        dep_list = spec.get("dependsOn", [])

        # Extract just the dependencies' names
        d_names = [d["name"] for d in dep_list if "name" in d]

        dependencies[name] = d_names
        meta_info[name] = namespace

        # Populate reverse dependencies
        for dep in d_names:
            reverse_deps[dep].append(name)

    roots = [node for node in dependencies if not dependencies[node]]
    return dependencies, reverse_deps, meta_info, roots

    # Identify root nodes (nodes with no dependencies)
    roots = [node for node in dependencies if not dependencies[node]]

def print_tree(title, root, graph, visited, prefix="", is_last=True):
    """
    Print a tree-like structure of nodes starting at root.

    Args:
        title: String to print before the tree
        root: Starting node
        graph: Dictionary of node -> list of connected nodes
        visited: Set of already visited nodes
        prefix: String prefix for current line (optional)
        is_last: Boolean indicating if this is the last child (optional)
    """
    connector = "└─ " if is_last else "├─ "
    print(f"{prefix}{connector}{root}")

    children = sorted(graph.get(root, []))
    if not children:
        return

    new_prefix = prefix + ("   " if is_last else "│  ")
    for i, child in enumerate(children):
        if child not in visited:  # Only print if not visited
            is_last_child = (i == len(children) - 1)
            print_tree(title, child, graph, visited, new_prefix, is_last_child)
            visited.add(child)

def print_reverse_tree(node, graph, visited=None, prefix="", is_last=True):
    """
    Print a tree-like structure flowing upwards from the node.

    Args:
        node: Starting node
        graph: Dictionary of node -> list of connected nodes
        visited: Set of already visited nodes (optional)
        prefix: String prefix for current line (optional)
        is_last: Boolean indicating if this is the last child (optional)
    """
    if visited is None:
        visited = set()
    if node in visited:
        return
    visited.add(node)

    children = graph.get(node, [])
    for i, child in enumerate(children[:-1]):
        print_reverse_tree(child, graph, visited, prefix + "  ", False)
    if children:
        print_reverse_tree(children[-1], graph, visited, prefix + "  ", True)

    connector = "┌─ " if is_last else "├─ "
    print(prefix + connector + node)

def collect_all_upstream(node, dependencies):
    """
    Get all upstream dependencies recursively.

    Args:
        node: Starting node
        dependencies: Dictionary of node -> list of dependencies

    Returns:
        set: All upstream dependencies
    """
    result = set()
    def dfs(n):
        for d in dependencies.get(n, []):
            if d not in result:
                result.add(d)
                dfs(d)
    dfs(node)
    return result

def collect_all_downstream(node, reverse_deps):
    """
    Get all downstream dependents recursively.

    Args:
        node: Starting node
        reverse_deps: Dictionary of node -> list of dependents

    Returns:
        set: All downstream dependents
    """
    result = set()
    def dfs(n):
        for c in reverse_deps.get(n, []):
            if c not in result:
                result.add(c)
                dfs(c)
    dfs(node)
    return result

def generate_dot(dependencies, reverse_deps, target):
    """
    Generate a DOT file visualization of the dependency graph.

    Args:
        dependencies: Dictionary of node -> list of dependencies
        reverse_deps: Dictionary of node -> list of dependents
        target: Target node to highlight (or None for complete graph)

    Output:
        Creates 'dependencies.dot' file with:
        - Left-to-right layout
        - Box-shaped nodes
        - Color coding for target, upstream, and downstream relationships
    """
    all_nodes = set(dependencies.keys()) | set(reverse_deps.keys())

    with open("dependencies.dot", "w") as f:
        # Add rankdir=LR to make the graph flow left-to-right
        f.write("digraph G {\n")
        f.write('  rankdir=LR;\n')
        # Make all nodes boxes by default
        f.write('  node [style=filled, fillcolor=white, fontname="Helvetica", shape=box];\n')

        if target:
            # Target-specific highlighting
            upstream_nodes = collect_all_upstream(target, dependencies)
            downstream_nodes = collect_all_downstream(target, reverse_deps)

            # Highlight the target node (now already a box by default)
            f.write(f'  "{target}" [fillcolor=yellow, penwidth=2];\n')

            # Color upstream chain differently (e.g., lightblue)
            for n in upstream_nodes:
                if n == target:
                    continue
                f.write(f'  "{n}" [fillcolor=lightblue];\n')

            # Color downstream chain differently (e.g., lightgreen)
            for n in downstream_nodes:
                if n == target:
                    continue
                if n in upstream_nodes:
                    # If node is both upstream and downstream, give it another color (e.g. orange)
                    f.write(f'  "{n}" [fillcolor=orange];\n')
                else:
                    f.write(f'  "{n}" [fillcolor=lightgreen];\n')

        # Draw edges
        for src in dependencies:
            for dst in dependencies[src]:
                color = "black"
                if target:
                    if src in upstream_nodes and dst in upstream_nodes:
                        color = "blue"
                    elif src in downstream_nodes and dst in downstream_nodes:
                        color = "green"
                    elif src == target or dst == target:
                        # If directly connected to target, maybe highlight in red
                        color = "red"
                f.write(f'  "{src}" -> "{dst}" [color={color}];\n')

        f.write("}\n")

def draw_ascii_box(target):
    """
    Draw an ASCII box around the target node.

    Args:
        target: String to put in the box
    """
    print("┌" + "─" * (len(target) + 2) + "┐")
    print(f"│ {target} │")
    print("└" + "─" * (len(target) + 2) + "┘")

def print_upstream_tree(root, graph, target, visited=None, prefix="", is_last=True):
    """
    Print the upstream dependencies of the target node.

    Args:
        root: Starting node
        graph: Dictionary of node -> list of connected nodes
        target: Target node to find in the tree
        visited: Set of already visited nodes (optional)
        prefix: String prefix for current line (optional)
        is_last: Boolean indicating if this is the last child (optional)

    Returns:
        bool: True if target was found in this branch
    """
    if visited is None:
        visited = set()
    if root in visited:
        return False
    visited.add(root)

    connector = "└─ " if is_last else "├─ "
    print(prefix + connector + root)
    children = graph.get(root, [])
    found = False
    for i, child in enumerate(children):
        child_is_last = (i == len(children) - 1)
        if child == target:
            print_upstream_tree(child, graph, target, visited, prefix + ("    " if is_last else "│   "), child_is_last)
            found = True
        else:
            if print_upstream_tree(child, graph, target, visited, prefix + ("    " if is_last else "│   "), child_is_last):
                found = True
    return found

def main():
    parser = argparse.ArgumentParser(description="Generate Flux Kustomization dependency graphs")
    parser.add_argument("--target", required=False, help="Name of the target Kustomization to highlight")
    args = parser.parse_args()

    data = yaml.safe_load(sys.stdin.read())
    items = data.get("items", [])
    dependencies, reverse_deps, meta_info, roots = build_graph(items)

    if not args.target:
        print("Complete dependency tree:")
        # Get all root nodes (nodes with no dependencies)
        root_nodes = set()
        for node in dependencies:
            if not any(node in deps for deps in dependencies.values()):
                root_nodes.add(node)

        # Print all roots and their dependencies in a connected tree
        visited = set()
        roots_list = sorted(root_nodes)
        for i, root in enumerate(roots_list):
            is_last_root = (i == len(roots_list) - 1)
            if root not in visited:
                print_tree("", root, dependencies, visited, "", is_last_root)
                visited.add(root)

        # Generate DOT file for complete graph
        generate_dot(dependencies, reverse_deps, None)
        print("\nGenerated dependencies.dot file. You can use `dot -Tpng dependencies.dot -o dependencies.png` to visualize.")
        return

    target = args.target
    if target not in dependencies and target not in reverse_deps:
        print(f"Target {target} not found in the provided kustomizations.")
        sys.exit(1)

    # Print the dependency flow
    upstream_deps = dependencies.get(target, [])
    downstream_deps = reverse_deps.get(target, [])

    # Print upstream dependencies (in reverse)
    if upstream_deps:
        for dep in upstream_deps[:-1]:
            print_reverse_tree(dep, dependencies, set(), "  ", False)
        if upstream_deps:
            print_reverse_tree(upstream_deps[-1], dependencies, set(), "  ", True)

    # Print the target in a box
    draw_ascii_box(target)

    # Print downstream dependencies
    if downstream_deps:
        # Start with the direct children of the target to avoid duplication
        visited = set([target])  # Mark target as visited
        for i, child in enumerate(sorted(downstream_deps)):
            is_last = (i == len(downstream_deps) - 1)
            print_tree("", child, reverse_deps, visited, prefix="  ", is_last=is_last)

    # Generate DOT file
    generate_dot(dependencies, reverse_deps, target)
    print("\nGenerated dependencies.dot file. You can use `dot -Tpng dependencies.dot -o dependencies.png` to visualize.")

if __name__ == "__main__":
    main()
