import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/node.dart';
import '../providers/node_provider.dart';
import '../widgets/node_editor.dart';

class NodeItem extends StatefulWidget {
  final Node node;
  final Node? parent;
  final Function(Node) onEdit;
  final Function(Node) onDelete;

  const NodeItem({
    Key? key,
    required this.node,
    this.parent,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<NodeItem> createState() => _NodeItemState();
}

class _NodeItemState extends State<NodeItem> {
  bool _isExpanded = true;
  bool _isDragging = false;
  bool _isHovering = false;
  bool _isTargeted = false;
  bool _showDetails = false; // New state for toggling details visibility

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.node.isExpanded;
  }

  @override
  void didUpdateWidget(NodeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.isExpanded != widget.node.isExpanded) {
      _isExpanded = widget.node.isExpanded;
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      Provider.of<NodeProvider>(context, listen: false)
          .toggleNodeExpansion(widget.node.id);
    });
  }

  void _toggleDetails() {
    setState(() {
      _showDetails = !_showDetails;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nodeProvider = Provider.of<NodeProvider>(context, listen: false);
    final depth = widget.node.depth;
    final hasChildren = widget.node.children.isNotEmpty;
    final indent = depth * 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Draggable Node with integrated DragTarget
        DragTarget<Node>(
          builder: (context, candidateData, rejectedData) {
            final isTargeted = candidateData.isNotEmpty;

            // Update state for targeted appearance - use didChangeDependencies instead of setState
            if (isTargeted != _isTargeted) {
              Future.microtask(() {
                if (mounted) {
                  setState(() {
                    _isTargeted = isTargeted;
                  });
                }
              });
            }

            return LongPressDraggable<Node>(
              // Use LongPressDraggable instead of Draggable for intentional drag actions
              data: widget.node,
              delay: const Duration(
                  milliseconds: 500), // Adjust delay to feel right

              // Make dragging more responsive
              maxSimultaneousDrags: 1,

              // Provide clear visual feedback
              feedback: Material(
                elevation: 8,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.7,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                  child: _buildNodeTitleOnly(context, 0, dragging: true),
                ),
              ),

              // Show a faded version when dragging
              childWhenDragging: Opacity(
                opacity: 0.2,
                child: _buildNodeCard(context, indent),
              ),

              // Track drag state
              onDragStarted: () => setState(() => _isDragging = true),
              onDragEnd: (_) => setState(() => _isDragging = false),
              onDraggableCanceled: (_, __) =>
                  setState(() => _isDragging = false),

              // The widget that can be dragged
              child: MouseRegion(
                onEnter: (_) => setState(() => _isHovering = true),
                onExit: (_) => setState(() => _isHovering = false),
                cursor: _isDragging
                    ? SystemMouseCursors.grabbing
                    : SystemMouseCursors.click,
                child: Stack(
                  children: [
                    // The main node card (with tap to show details)
                    GestureDetector(
                      onTap: _toggleDetails,
                      behavior: HitTestBehavior.opaque,
                      child: _buildNodeCard(context, indent),
                    ),

                    // Drop target indicator overlay
                    if (_isTargeted)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.secondary,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.add_circle_outline,
                              color: Theme.of(context).colorScheme.secondary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
          onWillAccept: (dragged) {
            if (dragged == null) return false;

            // Prevent moving into itself or its descendants
            if (dragged.id == widget.node.id) return false;

            // Prevent cyclic references
            if (_wouldCreateCycle(nodeProvider, dragged, widget.node))
              return false;

            // Check depth limit
            final maxChildDepth = nodeProvider.getMaxDepth(dragged);
            if (widget.node.depth + 1 + maxChildDepth > 5) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Maximum depth of 5 levels reached'),
                ),
              );
              return false;
            }

            return true;
          },
          onAccept: (dragged) {
            // Handle the drop as adding a child
            Future.microtask(() {
              final nodeProvider =
                  Provider.of<NodeProvider>(context, listen: false);
              bool success = nodeProvider.moveNodeToProvider(
                dragged: dragged,
                target: widget.node,
                position: 'inside',
              );

              if (success) {
                // Expand the node to show the newly added child
                if (!widget.node.isExpanded) {
                  nodeProvider.toggleNodeExpansion(widget.node.id);
                }

                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Added "${dragged.title}" as child of "${widget.node.title}"')),
                );
              }

              // Reset target state
              setState(() {
                _isTargeted = false;
              });
            });
          },
          onLeave: (_) {
            // Reset target state when drag leaves
            Future.microtask(() {
              setState(() {
                _isTargeted = false;
              });
            });
          },
        ),

        // Children (recursive) - simplified to just have padding instead of connectors
        if (_isExpanded && hasChildren)
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.node.children.map((child) {
                return NodeItem(
                  node: child,
                  parent: widget.node,
                  onEdit: widget.onEdit,
                  onDelete: widget.onDelete,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // Title-only version for drag preview
  Widget _buildNodeTitleOnly(BuildContext context, double indent,
      {bool dragging = false}) {
    final hasChildren = widget.node.children.isNotEmpty;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: dragging || _isHovering || _isTargeted
            ? _isTargeted
                ? theme.colorScheme.secondary.withOpacity(0.1)
                : theme.colorScheme.primary.withOpacity(0.1)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isTargeted
              ? theme.colorScheme.secondary
              : (dragging || _isHovering)
                  ? theme.colorScheme.primary
                  : Colors.transparent,
          width: 1,
        ),
        boxShadow: dragging || _isHovering || _isTargeted
            ? [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.2),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(width: indent),

          // Expand/Collapse Toggle - more compact
          if (hasChildren)
            SizedBox(
              width: 30, // Reduced from 40
              height: 30, // Reduced from 40
              child: GestureDetector(
                onTap: _toggleExpanded,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  _isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 18, // Smaller icon
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            )
          else
            const SizedBox(width: 16), // Smaller indentation

          // Node Title Only with overflow handling
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                widget.node.title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Action Buttons (tighter spacing, pushed right)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add Child button - more compact
              SizedBox(
                width: 32, // Reduced from 40
                height: 32, // Reduced from 40
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  onPressed: () {
                    showNodeEditor(
                      context: context,
                      node: null,
                      parent: widget.node,
                      onSubmit: (newNode) {
                        final nodeProvider =
                            Provider.of<NodeProvider>(context, listen: false);
                        // Don't allow adding if already at max depth
                        if (widget.node.depth >= 4) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Maximum depth of 5 levels reached')),
                          );
                          return;
                        }

                        // Add child node to this parent with properties from newNode
                        nodeProvider.addNodeToProvider(
                          parent: widget.node,
                          title: newNode.title,
                          notes: newNode.notes,
                          tags: newNode.tags,
                        );
                      },
                    );
                  },
                  tooltip: 'Add Child',
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ),

              // Edit button - more compact
              SizedBox(
                width: 32, // Reduced from 40
                height: 32, // Reduced from 40
                child: IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => widget.onEdit(widget.node),
                  tooltip: 'Edit',
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ),

              // Delete button - more compact
              SizedBox(
                width: 32, // Reduced from 40
                height: 32, // Reduced from 40
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => widget.onDelete(widget.node),
                  tooltip: 'Delete',
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNodeCard(BuildContext context, double indent,
      {bool dragging = false}) {
    final hasChildren = widget.node.children.isNotEmpty;
    final theme = Theme.of(context);

    // Format dates
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final createdDateStr = dateFormat.format(widget.node.createdAt);
    final editedDateStr = dateFormat.format(widget.node.lastEditedAt);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: dragging || _isHovering || _isTargeted
            ? _isTargeted
                ? theme.colorScheme.secondary.withOpacity(0.1)
                : theme.colorScheme.primary.withOpacity(0.1)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isTargeted
              ? theme.colorScheme.secondary
              : (dragging || _isHovering)
                  ? theme.colorScheme.primary
                  : Colors.transparent,
          width: 1,
        ),
        boxShadow: dragging || _isHovering || _isTargeted
            ? [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.2),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row (always visible)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                SizedBox(width: indent),

                // Expand/Collapse Toggle - more compact
                if (hasChildren)
                  SizedBox(
                    width: 30, // Reduced from 40
                    height: 30, // Reduced from 40
                    child: GestureDetector(
                      onTap: _toggleExpanded,
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        _isExpanded ? Icons.expand_more : Icons.chevron_right,
                        size: 18, // Smaller icon
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 16), // Smaller indentation

                // Node Title with indicator and overflow handling
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            widget.node.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      // Show indicator if details are available
                      if ((widget.node.notes != null &&
                              widget.node.notes!.isNotEmpty) ||
                          (widget.node.tags != null &&
                              widget.node.tags!.isNotEmpty))
                        Icon(
                          _showDetails ? Icons.unfold_less : Icons.unfold_more,
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                    ],
                  ),
                ),

                // Action Buttons (tighter spacing, pushed right)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Add Child button - more compact
                    SizedBox(
                      width: 32, // Reduced from 40
                      height: 32, // Reduced from 40
                      child: IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        onPressed: () {
                          showNodeEditor(
                            context: context,
                            node: null,
                            parent: widget.node,
                            onSubmit: (newNode) {
                              final nodeProvider = Provider.of<NodeProvider>(
                                  context,
                                  listen: false);
                              // Don't allow adding if already at max depth
                              if (widget.node.depth >= 4) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Maximum depth of 5 levels reached')),
                                );
                                return;
                              }

                              // Add child node to this parent with properties from newNode
                              nodeProvider.addNodeToProvider(
                                parent: widget.node,
                                title: newNode.title,
                                notes: newNode.notes,
                                tags: newNode.tags,
                              );
                            },
                          );
                        },
                        tooltip: 'Add Child',
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ),

                    // Edit button - more compact
                    SizedBox(
                      width: 32, // Reduced from 40
                      height: 32, // Reduced from 40
                      child: IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => widget.onEdit(widget.node),
                        tooltip: 'Edit',
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ),

                    // Delete button - more compact
                    SizedBox(
                      width: 32, // Reduced from 40
                      height: 32, // Reduced from 40
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => widget.onDelete(widget.node),
                        tooltip: 'Delete',
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Details section (only visible when expanded)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _showDetails ? null : 0,
            padding: _showDetails
                ? EdgeInsets.only(left: indent + 28, right: 16, bottom: 8)
                : EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(),
            child: _showDetails
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Notes section (if available)
                      if (widget.node.notes != null &&
                          widget.node.notes!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            widget.node.notes!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ),

                      // Tags section (if available)
                      if (widget.node.tags != null &&
                          widget.node.tags!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4, // Added run spacing for mobile wrap
                            children: widget.node.tags!.map((tag) {
                              return Chip(
                                label: Text(tag),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: -2),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                labelStyle: const TextStyle(fontSize: 10),
                              );
                            }).toList(),
                          ),
                        ),

                      // Timestamp information (always show in details)
                      Text(
                        'Created: $createdDateStr · Edited: $editedDateStr',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.textTheme.bodySmall?.color
                              ?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ],
      ),
    );
  }

  bool _wouldCreateCycle(NodeProvider provider, Node dragged, Node target) {
    Node? current = target;

    // Navigate up the tree to check if target is a descendant of dragged
    while (current != null) {
      if (current.id == dragged.id) {
        return true; // Would create a cycle
      }
      if (current.parentId == null) {
        // Check if it's a root node
        return false;
      }

      // Find the parent in rootNodes first
      Node? parent;
      for (final root in provider.rootNodes) {
        if (root.id == current.parentId) {
          parent = root;
          break;
        }
      }

      // If not found in root, look elsewhere
      if (parent == null) {
        parent = provider.findNodeById(current.parentId!);
      }

      current = parent;
    }

    return false;
  }
}
