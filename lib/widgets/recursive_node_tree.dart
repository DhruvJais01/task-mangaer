import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/node_provider.dart';

// A truly recursive implementation that can display nodes at any depth
class RecursiveNodeTree extends StatelessWidget {
  final Node rootNode;
  final Function(Node)? onNodeTap;
  final Function(Node)? onAddChild;
  final Function(Node)? onEdit;
  final Function(Node)? onDelete;

  const RecursiveNodeTree({
    super.key,
    required this.rootNode,
    this.onNodeTap,
    this.onAddChild,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: rootNode.children.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 100),
                    Icon(
                      Icons.sentiment_dissatisfied,
                      size: 64,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No items yet',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to add your first item',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top level drop target
                  _buildSiblingDropTarget(context, null, -1, rootNode.id),
                  // Render each child node recursively
                  ...rootNode.children.asMap().entries.map((entry) {
                    final index = entry.key;
                    final node = entry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RecursiveNodeItem(
                          node: node,
                          onNodeTap: onNodeTap,
                          onAddChild: onAddChild,
                          onEdit: onEdit,
                          onDelete: onDelete,
                          level: 0, // Start at level 0
                          parentId: rootNode.id,
                          index: index,
                        ),
                        // Drop target for sibling after this node
                        _buildSiblingDropTarget(
                            context, node, index, rootNode.id),
                      ],
                    );
                  }),
                ],
              ),
      ),
    );
  }

  // Build a drop target for placing nodes as siblings
  Widget _buildSiblingDropTarget(
      BuildContext context, Node? previousNode, int index, String parentId) {
    return DragTarget<Map<String, dynamic>>(
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        return Container(
          height: 10,
          margin: const EdgeInsets.symmetric(vertical: 2.0),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
      onAcceptWithDetails: (data) {
        final nodeProvider = Provider.of<NodeProvider>(context, listen: false);
        final draggedNodeId = data['nodeId'] as String;
        final sourceParentId = data['parentId'] as String;
        final sourceIndex = data['index'] as int;

        // If the dragged node comes from the same parent
        if (sourceParentId == parentId) {
          final targetIndex = index < sourceIndex ? index + 1 : index;
          nodeProvider.reorderNodes(parentId, sourceIndex, targetIndex);
        } else {
          // Move to a new parent
          nodeProvider.moveNode(draggedNodeId, parentId);

          // If we need to put it at a specific position within the new parent
          if (index >= 0) {
            // Find the node's new index in the new parent
            final parent = nodeProvider.findNodeById(parentId);
            if (parent != null) {
              final newNodeIndex =
                  parent.children.indexWhere((n) => n.id == draggedNodeId);
              if (newNodeIndex >= 0 && newNodeIndex != index) {
                nodeProvider.reorderNodes(parentId, newNodeIndex, index + 1);
              }
            }
          }
        }
      },
    );
  }
}

class RecursiveNodeItem extends StatefulWidget {
  final Node node;
  final int level;
  final int index;
  final String parentId;
  final Function(Node)? onNodeTap;
  final Function(Node)? onAddChild;
  final Function(Node)? onEdit;
  final Function(Node)? onDelete;

  const RecursiveNodeItem({
    super.key,
    required this.node,
    required this.level,
    required this.index,
    required this.parentId,
    this.onNodeTap,
    this.onAddChild,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<RecursiveNodeItem> createState() => _RecursiveNodeItemState();
}

class _RecursiveNodeItemState extends State<RecursiveNodeItem> {
  late bool _isExpanded;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.node.isExpanded; // Initialize with node's state
  }

  @override
  void didUpdateWidget(RecursiveNodeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.isExpanded != widget.node.isExpanded) {
      _isExpanded = widget.node.isExpanded;
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      // Update the provider state
      final nodeProvider = Provider.of<NodeProvider>(context, listen: false);
      nodeProvider.toggleNodeExpansion(widget.node.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasChildren = widget.node.children.isNotEmpty;
    final theme = Theme.of(context);
    final indentation = (widget.level * 24.0); // 24dp indentation per level

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The node item itself with drag/drop support
        LongPressDraggable<Map<String, dynamic>>(
          data: {
            'nodeId': widget.node.id,
            'parentId': widget.parentId,
            'index': widget.index,
          },
          onDragStarted: () {
            setState(() {
              _isDragging = true;
            });
          },
          onDragEnd: (details) {
            setState(() {
              _isDragging = false;
            });
          },
          onDraggableCanceled: (velocity, offset) {
            setState(() {
              _isDragging = false;
            });
          },
          feedback: Material(
            elevation: 4.0,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.drag_indicator,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      widget.node.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _buildNodeCard(context, hasChildren, theme, indentation),
          ),
          child: _isDragging
              ? Container()
              : _buildNodeCard(context, hasChildren, theme, indentation),
        ),

        // Inner drop target - drop inside this node to make it a child
        if (!_isDragging)
          Padding(
            padding: EdgeInsets.only(left: indentation + 40),
            child: DragTarget<Map<String, dynamic>>(
              builder: (context, candidateData, rejectedData) {
                final isActive = candidateData.isNotEmpty;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: hasChildren && _isExpanded ? 0 : 30,
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 4, bottom: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.tertiary.withOpacity(0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isActive
                        ? Border.all(
                            color: theme.colorScheme.tertiary,
                            width: 1,
                            style: BorderStyle.solid,
                          )
                        : null,
                  ),
                  child: isActive
                      ? Center(
                          child: Text(
                            'Drop to add as child',
                            style: TextStyle(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.5),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : null,
                );
              },
              onAcceptWithDetails: (data) {
                final nodeProvider =
                    Provider.of<NodeProvider>(context, listen: false);
                final draggedNodeId = data['nodeId'] as String;

                // Don't allow a node to become its own child or ancestor's child (would create a cycle)
                if (draggedNodeId != widget.node.id &&
                    !_isDescendantOf(
                        nodeProvider, draggedNodeId, widget.node.id)) {
                  nodeProvider.moveNode(draggedNodeId, widget.node.id);

                  // Expand this node to show the newly added child
                  if (!_isExpanded) {
                    _toggleExpanded();
                  }
                }
              },
            ),
          ),

        // Recursively render children if expanded
        if (_isExpanded && hasChildren)
          Padding(
            padding: EdgeInsets.only(left: indentation),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First sibling drop target
                _buildChildDropTarget(context, -1, widget.node.id),

                // Child nodes with drop targets between them
                ...widget.node.children.asMap().entries.map((entry) {
                  final childIndex = entry.key;
                  final childNode = entry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RecursiveNodeItem(
                        node: childNode,
                        level: widget.level + 1, // Increment level for children
                        index: childIndex,
                        parentId: widget.node.id,
                        onNodeTap: widget.onNodeTap,
                        onAddChild: widget.onAddChild,
                        onEdit: widget.onEdit,
                        onDelete: widget.onDelete,
                      ),
                      // Drop target after each child
                      _buildChildDropTarget(
                          context, childIndex, widget.node.id),
                    ],
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  // Helper to check if a node is a descendant of another node
  bool _isDescendantOf(
      NodeProvider provider, String possibleAncestorId, String nodeId) {
    Node? current = provider.findNodeById(nodeId);
    if (current == null) return false;

    // Navigate up the tree checking each parent
    Node? parent = provider.findParentNode(current.id);
    while (parent != null) {
      if (parent.id == possibleAncestorId) {
        return true;
      }
      parent = provider.findParentNode(parent.id);
    }

    return false;
  }

  // Build the main card for the node
  Widget _buildNodeCard(BuildContext context, bool hasChildren, ThemeData theme,
      double indentation) {
    return InkWell(
      onTap: () => widget.onNodeTap?.call(widget.node),
      child: Padding(
        padding: EdgeInsets.only(left: indentation),
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Expand/collapse icon
                if (hasChildren)
                  GestureDetector(
                    onTap: _toggleExpanded,
                    child: Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 24,
                      color: theme.colorScheme.primary,
                    ),
                  )
                else
                  const SizedBox(width: 24), // Empty space for alignment

                const SizedBox(width: 12),

                // Drag handle
                Icon(
                  Icons.drag_indicator,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  size: 20,
                ),

                const SizedBox(width: 12),

                // Node title and details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.node.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.node.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            widget.node.notes,
                            style: theme.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (widget.node.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Wrap(
                            spacing: 4.0,
                            children: widget.node.tags
                                .map((tag) => Chip(
                                      label: Text(
                                        tag,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      padding: EdgeInsets.zero,
                                      labelPadding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 0,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),

                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: theme.colorScheme.primary,
                      tooltip: 'Add Child',
                      onPressed: () => widget.onAddChild?.call(widget.node),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      color: theme.colorScheme.secondary,
                      tooltip: 'Edit',
                      onPressed: () => widget.onEdit?.call(widget.node),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: theme.colorScheme.error,
                      tooltip: 'Delete',
                      onPressed: () => widget.onDelete?.call(widget.node),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build drop target for between child nodes
  Widget _buildChildDropTarget(
      BuildContext context, int index, String parentId) {
    return DragTarget<Map<String, dynamic>>(
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: isActive ? 20 : 6,
          margin: const EdgeInsets.symmetric(vertical: 2.0),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
      onAcceptWithDetails: (data) {
        final nodeProvider = Provider.of<NodeProvider>(context, listen: false);
        final draggedNodeId = data['nodeId'] as String;
        final sourceParentId = data['parentId'] as String;
        final sourceIndex = data['index'] as int;

        // Don't allow a node to become its own child or ancestor's child
        if (draggedNodeId != parentId &&
            !_isDescendantOf(nodeProvider, draggedNodeId, parentId)) {
          // If the dragged node comes from the same parent
          if (sourceParentId == parentId) {
            final targetIndex = index < sourceIndex ? index + 1 : index;
            nodeProvider.reorderNodes(parentId, sourceIndex, targetIndex);
          } else {
            // Move to a new parent
            nodeProvider.moveNode(draggedNodeId, parentId);

            // If we need to put it at a specific position within the new parent
            if (index >= 0) {
              // Find the node's new index in the new parent
              final parent = nodeProvider.findNodeById(parentId);
              if (parent != null) {
                final newNodeIndex =
                    parent.children.indexWhere((n) => n.id == draggedNodeId);
                if (newNodeIndex >= 0 && newNodeIndex != index) {
                  nodeProvider.reorderNodes(parentId, newNodeIndex, index + 1);
                }
              }
            }
          }
        }
      },
    );
  }
}
