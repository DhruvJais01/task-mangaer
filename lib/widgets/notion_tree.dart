import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/node_provider.dart';

/// Defines the position where a node can be dropped
enum DropPosition {
  above,
  inside,
  below,
}

/// A Notion-like hierarchical tree that supports flexible drag-and-drop
class NotionTree extends StatefulWidget {
  final Node rootNode;
  final Function(Node)? onNodeTap;
  final Function(Node)? onAddChild;
  final Function(Node)? onEdit;
  final Function(Node)? onDelete;

  const NotionTree({
    super.key,
    required this.rootNode,
    this.onNodeTap,
    this.onAddChild,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<NotionTree> createState() => _NotionTreeState();
}

class _NotionTreeState extends State<NotionTree> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: widget.rootNode.children.isEmpty
            ? _buildEmptyState(context)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top drop target above all nodes
                  NotionDropTarget(
                    position: DropPosition.above,
                    parentNode: widget.rootNode,
                    index: 0,
                    isRoot: true,
                  ),
                  // Render root children
                  ...widget.rootNode.children.asMap().entries.map((entry) {
                    final index = entry.key;
                    final node = entry.value;
                    return NotionNodeItem(
                      node: node,
                      parentNode: widget.rootNode,
                      index: index,
                      level: 0,
                      onNodeTap: widget.onNodeTap,
                      onAddChild: widget.onAddChild,
                      onEdit: widget.onEdit,
                      onDelete: widget.onDelete,
                    );
                  }),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.text_snippet_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'No blocks yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first block',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// Represents a single node in the Notion-like tree
class NotionNodeItem extends StatefulWidget {
  final Node node;
  final Node parentNode;
  final int index;
  final int level;
  final Function(Node)? onNodeTap;
  final Function(Node)? onAddChild;
  final Function(Node)? onEdit;
  final Function(Node)? onDelete;

  const NotionNodeItem({
    super.key,
    required this.node,
    required this.parentNode,
    required this.index,
    required this.level,
    this.onNodeTap,
    this.onAddChild,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<NotionNodeItem> createState() => _NotionNodeItemState();
}

class _NotionNodeItemState extends State<NotionNodeItem> {
  bool _isExpanded = true;
  bool _isDragging = false;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.node.isExpanded;
  }

  @override
  void didUpdateWidget(NotionNodeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.isExpanded != widget.node.isExpanded) {
      _isExpanded = widget.node.isExpanded;
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      final nodeProvider = Provider.of<NodeProvider>(context, listen: false);
      nodeProvider.toggleNodeExpansion(widget.node.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasChildren = widget.node.children.isNotEmpty;
    final theme = Theme.of(context);
    final indentation = widget.level * 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Node content with drag and drop
        LongPressDraggable<Map<String, dynamic>>(
          data: {
            'nodeId': widget.node.id,
            'parentId': widget.parentNode.id,
            'index': widget.index,
          },
          onDragStarted: () => setState(() => _isDragging = true),
          onDragEnd: (_) => setState(() => _isDragging = false),
          onDraggableCanceled: (_, __) => setState(() => _isDragging = false),
          feedback: _buildDragFeedback(theme),
          child: _isDragging
              ? Container() // Hide the original when dragging
              : MouseRegion(
                  onEnter: (_) => setState(() => _isHovering = true),
                  onExit: (_) => setState(() => _isHovering = false),
                  child: Stack(
                    children: [
                      // Node card
                      Padding(
                        padding: EdgeInsets.only(left: indentation),
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 2.0),
                          elevation: _isHovering ? 2 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: _isHovering
                                ? BorderSide(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.5),
                                    width: 1,
                                  )
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            onTap: () => widget.onNodeTap?.call(widget.node),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Toggle and drag handle
                                  Column(
                                    children: [
                                      if (hasChildren)
                                        IconButton(
                                          icon: Icon(
                                            _isExpanded
                                                ? Icons.keyboard_arrow_down
                                                : Icons.keyboard_arrow_right,
                                            size: 18,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          iconSize: 18,
                                          splashRadius: 18,
                                          visualDensity: VisualDensity.compact,
                                          onPressed: _toggleExpanded,
                                        )
                                      else
                                        const SizedBox(width: 18),
                                      const SizedBox(height: 8),
                                      Icon(
                                        Icons.drag_indicator,
                                        size: 16,
                                        color: _isHovering
                                            ? theme.colorScheme.onSurface
                                                .withOpacity(0.6)
                                            : theme.colorScheme.onSurface
                                                .withOpacity(0.3),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),

                                  // Node content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.node.title,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (widget.node.notes.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              widget.node.notes,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withOpacity(0.7),
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        if (widget.node.tags.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8.0),
                                            child: Wrap(
                                              spacing: 4.0,
                                              runSpacing: 4.0,
                                              children: widget.node.tags
                                                  .map((tag) =>
                                                      _buildTag(tag, theme))
                                                  .toList(),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Action buttons
                                  if (_isHovering)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          tooltip: 'Add Child',
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          iconSize: 18,
                                          splashRadius: 18,
                                          onPressed: () => widget.onAddChild
                                              ?.call(widget.node),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          tooltip: 'Edit',
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          iconSize: 18,
                                          splashRadius: 18,
                                          onPressed: () =>
                                              widget.onEdit?.call(widget.node),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          tooltip: 'Delete',
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          iconSize: 18,
                                          splashRadius: 18,
                                          onPressed: () => widget.onDelete
                                              ?.call(widget.node),
                                          color: theme.colorScheme.error,
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Inside drop target indicator (shown when something is dragged over)
                      if (_isHovering)
                        Positioned(
                          left: indentation + 36,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 3,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  theme.colorScheme.tertiary.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),

        // Drop target below this node
        NotionDropTarget(
          position: DropPosition.below,
          parentNode: widget.parentNode,
          index: widget.index + 1,
        ),

        // Drop target inside this node
        NotionDropTarget(
          position: DropPosition.inside,
          parentNode: widget.node,
          index: 0,
        ),

        // Recursive children rendering
        if (_isExpanded && hasChildren)
          Padding(
            padding: const EdgeInsets.only(left: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...widget.node.children.asMap().entries.map((entry) {
                  final childIndex = entry.key;
                  final childNode = entry.value;

                  return NotionNodeItem(
                    node: childNode,
                    parentNode: widget.node,
                    index: childIndex,
                    level: widget.level + 1,
                    onNodeTap: widget.onNodeTap,
                    onAddChild: widget.onAddChild,
                    onEdit: widget.onEdit,
                    onDelete: widget.onDelete,
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDragFeedback(ThemeData theme) {
    return Material(
      elevation: 6.0,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.drag_indicator,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.node.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String tag, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 11,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// A drop target for Notion-like drag and drop operations
class NotionDropTarget extends StatefulWidget {
  final DropPosition position;
  final Node parentNode;
  final int index;
  final bool isRoot;

  const NotionDropTarget({
    super.key,
    required this.position,
    required this.parentNode,
    required this.index,
    this.isRoot = false,
  });

  @override
  State<NotionDropTarget> createState() => _NotionDropTargetState();
}

class _NotionDropTargetState extends State<NotionDropTarget> {
  bool _isActive = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nodeProvider = Provider.of<NodeProvider>(context, listen: false);

    // Different drop targets have different visual styles
    late Widget dropIndicator;

    if (widget.position == DropPosition.above ||
        widget.position == DropPosition.below) {
      // Horizontal line for above/below
      dropIndicator = Container(
        height: _isActive ? 4 : 2,
        margin: const EdgeInsets.symmetric(vertical: 1.0),
        decoration: BoxDecoration(
          color: _isActive ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    } else {
      // Left vertical bar for inside
      dropIndicator = Container(
        height: 30,
        width: double.infinity,
        margin: const EdgeInsets.only(left: 24, top: 2, bottom: 2),
        decoration: BoxDecoration(
          color: _isActive
              ? theme.colorScheme.tertiary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: _isActive
              ? Border.all(
                  color: theme.colorScheme.tertiary.withOpacity(0.3),
                  width: 1,
                )
              : null,
        ),
        child: _isActive
            ? Center(
                child: Text(
                  'Insert as child',
                  style: TextStyle(
                    color: theme.colorScheme.tertiary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            : null,
      );
    }

    return DragTarget<Map<String, dynamic>>(
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: _getDropTargetHeight(),
          child: dropIndicator,
        );
      },
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        final draggedNodeId = data['nodeId'] as String;

        // Don't allow dropping on itself or its children
        if (draggedNodeId == widget.parentNode.id) {
          return false;
        }

        // For inside drops, check for cycles
        if (widget.position == DropPosition.inside) {
          final result = !_wouldCreateCycle(
              nodeProvider, draggedNodeId, widget.parentNode.id);
          if (result) {
            setState(() => _isActive = true);
          }
          return result;
        }

        setState(() => _isActive = true);
        return true;
      },
      onAcceptWithDetails: (data) {
        final draggedNodeId = data['nodeId'] as String;
        final sourceParentId = data['parentId'] as String;
        final sourceIndex = data['index'] as int;

        _moveNode(
          context,
          draggedNodeId,
          sourceParentId,
          sourceIndex,
          widget.parentNode.id,
          widget.index,
          widget.position,
        );

        setState(() => _isActive = false);
      },
      onLeave: (_) {
        setState(() => _isActive = false);
      },
    );
  }

  double _getDropTargetHeight() {
    if (widget.position == DropPosition.above ||
        widget.position == DropPosition.below) {
      return _isActive ? 12.0 : 4.0;
    } else {
      return _isActive ? 40.0 : 0.0;
    }
  }

  bool _wouldCreateCycle(
      NodeProvider provider, String draggedNodeId, String targetNodeId) {
    Node? current = provider.findNodeById(targetNodeId);

    // Navigate up the tree checking each parent
    while (current != null) {
      if (current.id == draggedNodeId) {
        return true; // Would create a cycle
      }
      current = current.parentId != null
          ? provider.findNodeById(current.parentId!)
          : null;
    }

    return false;
  }

  void _moveNode(
    BuildContext context,
    String draggedNodeId,
    String sourceParentId,
    int sourceIndex,
    String targetParentId,
    int targetIndex,
    DropPosition position,
  ) {
    final nodeProvider = Provider.of<NodeProvider>(context, listen: false);

    // Handle the move based on position
    if (position == DropPosition.above || position == DropPosition.below) {
      // If it's from the same parent, just reorder
      if (sourceParentId == targetParentId) {
        final newIndex =
            position == DropPosition.above ? targetIndex : targetIndex;
        final adjustedIndex = sourceIndex < newIndex ? newIndex - 1 : newIndex;
        nodeProvider.reorderNodes(targetParentId, sourceIndex, adjustedIndex);
      } else {
        // Move to new parent at specific position
        nodeProvider.moveNodeToPosition(draggedNodeId, targetParentId,
            position == DropPosition.above ? targetIndex : targetIndex);
      }
    } else {
      // Make it a child of the target node
      nodeProvider.moveNode(draggedNodeId, targetParentId);

      // Expand the parent to show the newly added child
      if (targetParentId != 'root') {
        final targetNode = nodeProvider.findNodeById(targetParentId);
        if (targetNode != null && !targetNode.isExpanded) {
          nodeProvider.toggleNodeExpansion(targetParentId);
        }
      }
    }
  }
}
