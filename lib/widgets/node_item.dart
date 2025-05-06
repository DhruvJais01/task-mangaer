import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Add timer import
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

  // Track the current drop zone in state
  String _currentDropZone = "inside";

  // New state for tracking top/bottom drop edge animations
  bool _showTopDropZone = false;
  bool _showBottomDropZone = false;

  // New state variables for tracking locked drop zones
  bool _topDropZoneLocked = false;
  bool _bottomDropZoneLocked = false;

  // Timer variables for delayed activation
  Timer? _topDropZoneTimer;
  Timer? _bottomDropZoneTimer;

  // Edge threshold in logical pixels - increase for better touch targets
  final double edgeThreshold = 20.0;

  // Threshold for significant movement
  final double movementThreshold = 40.0;

  // Last position for tracking movement
  Offset? _lastDragPosition;

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

  @override
  void dispose() {
    // Cancel any active timers
    _topDropZoneTimer?.cancel();
    _bottomDropZoneTimer?.cancel();
    super.dispose();
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

  // New method to update top/bottom drop zone visibility
  void _updateEdgeDropZones(bool isEntering,
      {bool isTop = false, bool isBottom = false}) {
    if (!mounted) return;

    // For deactivation, only proceed if the zones aren't locked or we're forcing deactivation
    if (!isEntering) {
      setState(() {
        if (isTop) {
          // Cancel any pending timer
          _topDropZoneTimer?.cancel();
          _topDropZoneTimer = null;

          if (!_topDropZoneLocked) {
            _showTopDropZone = false;
          }
        }
        if (isBottom) {
          // Cancel any pending timer
          _bottomDropZoneTimer?.cancel();
          _bottomDropZoneTimer = null;

          if (!_bottomDropZoneLocked) {
            _showBottomDropZone = false;
          }
        }
      });
      return;
    }

    // For activation, use a delay to prevent flickering
    if (isTop) {
      // Cancel existing timer
      _topDropZoneTimer?.cancel();

      // If already locked or shown, just ensure it stays visible
      if (_topDropZoneLocked || _showTopDropZone) {
        setState(() {
          _showTopDropZone = true;
        });
        return;
      }

      // Start a new timer for delayed activation
      _topDropZoneTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted) {
          setState(() {
            _showTopDropZone = true;
            _topDropZoneLocked = true; // Lock it once activated
          });
        }
      });
    }

    if (isBottom) {
      // Cancel existing timer
      _bottomDropZoneTimer?.cancel();

      // If already locked or shown, just ensure it stays visible
      if (_bottomDropZoneLocked || _showBottomDropZone) {
        setState(() {
          _showBottomDropZone = true;
        });
        return;
      }

      // Start a new timer for delayed activation
      _bottomDropZoneTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted) {
          setState(() {
            _showBottomDropZone = true;
            _bottomDropZoneLocked = true; // Lock it once activated
          });
        }
      });
    }
  }

  // Method to reset all drop zone locks
  void _resetDropZoneLocks() {
    if (mounted) {
      setState(() {
        _topDropZoneLocked = false;
        _bottomDropZoneLocked = false;
        _showTopDropZone = false;
        _showBottomDropZone = false;
      });
    }

    // Cancel any pending timers
    _topDropZoneTimer?.cancel();
    _topDropZoneTimer = null;
    _bottomDropZoneTimer?.cancel();
    _bottomDropZoneTimer = null;
  }

  // Helper to show snackbar feedback
  void _showReorderFeedback(Node draggedNode, String position) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Moved "${draggedNode.title}" $position "${widget.node.title}"'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Update the drop zone based on drag position
  void _updateDropZone(Offset position, Size nodeSize) {
    final oldDropZone = _currentDropZone;

    // Using more balanced thresholds for better usability
    // Top 30% = before, bottom 30% = after, middle 40% = inside
    final topThresholdPercentage = 0.30;
    final bottomThresholdPercentage = 0.70;

    if (position.dy < nodeSize.height * topThresholdPercentage) {
      _currentDropZone = "before";
    } else if (position.dy > nodeSize.height * bottomThresholdPercentage) {
      _currentDropZone = "after";
    } else {
      _currentDropZone = "inside";
    }

    // If zone changed, trigger a rebuild for visual feedback
    if (oldDropZone != _currentDropZone) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodeProvider = Provider.of<NodeProvider>(context, listen: false);
    final depth = widget.node.depth;
    final hasChildren = widget.node.children.isNotEmpty;
    final indent = depth * 1.0;
    final isSearchActive = nodeProvider.isSearchActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Animated top drop zone that appears between nodes
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          height: _showTopDropZone ? 48.0 : 0.0,
          margin: EdgeInsets.only(left: indent + 16, right: 16),
          child: _showTopDropZone
              ? DragTarget<Node>(
                  builder: (context, candidateData, rejectedData) {
                    final isActive = candidateData.isNotEmpty;
                    return Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isActive || _topDropZoneLocked
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2)
                            : Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.15),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: isActive || _topDropZoneLocked ? 3 : 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isActive || _topDropZoneLocked
                            ? [
                                BoxShadow(
                                  color: Theme.of(context)
                                      .shadowColor
                                      .withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_upward,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Place above",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  onWillAccept: (dragged) {
                    if (dragged == null) return false;
                    if (dragged.id == widget.node.id) return false;
                    // Prevent cyclic references
                    if (nodeProvider.isDescendantOf(dragged, widget.node))
                      return false;
                    return true;
                  },
                  onAccept: (dragged) {
                    nodeProvider.insertNodeBefore(dragged, widget.node);
                    _resetDropZoneLocks();
                    _showReorderFeedback(dragged, "above");
                  },
                  onLeave: (_) {
                    _updateEdgeDropZones(false, isTop: true);
                  },
                )
              : null,
        ),

        // Draggable Node with integrated DragTarget
        DragTarget<Node>(
          builder: (context, candidateData, rejectedData) {
            final isTargeted = candidateData.isNotEmpty;
            // final isTargeted = true;

            // if (mounted) {
            //   setState(() {
            //     _isTargeted = true;
            //   });
            // }

            // Update state for targeted appearance - use didChangeDependencies instead of setState
            if (isTargeted != _isTargeted) {
              Future.microtask(() {
                if (mounted) {
                  setState(() {
                    _isTargeted = true;
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
                  padding: const EdgeInsets.all(12),
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
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.drag_indicator,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.node.title,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Show a faded version when dragging
              childWhenDragging: Opacity(
                opacity: 0.2,
                child: _buildNodeCard(context, indent),
              ),

              // Track drag state
              onDragStarted: () => setState(() => _isDragging = true),
              onDragEnd: (_) {
                setState(() {
                  _isDragging = false;
                });
                // Reset all drop zone states
                _resetDropZoneLocks();
              },
              onDraggableCanceled: (_, __) {
                setState(() {
                  _isDragging = false;
                });
                // Reset all drop zone states
                _resetDropZoneLocks();
              },

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

                    // Drop target indicator overlay for different zones
                    if (_isTargeted) _buildTargetOverlay(context, hasChildren),
                  ],
                ),
              ),
            );
          },
          // Use onWillAcceptWithDetails to get position information
          onWillAcceptWithDetails: (DragTargetDetails<Node> details) {
            final dragged = details.data;
            if (dragged == null) return false;

            final nodeProvider =
                Provider.of<NodeProvider>(context, listen: false);
            final isSearchActive = nodeProvider.isSearchActive;

            // Disable dragging if search is active
            if (isSearchActive) return false;

            // Calculate if we're in the top edge, bottom edge, or center
            final RenderBox renderBox = context.findRenderObject() as RenderBox;
            final size = renderBox.size;
            final localPosition = renderBox.globalToLocal(details.offset);

            // Track significant movement
            bool hasSignificantMovement = false;
            if (_lastDragPosition != null) {
              final distance = (_lastDragPosition! - localPosition).distance;
              hasSignificantMovement = distance > movementThreshold;

              // If significant movement, unlock zones
              if (hasSignificantMovement) {
                _topDropZoneLocked = false;
                _bottomDropZoneLocked = false;
              }
            }
            _lastDragPosition = localPosition;

            // Show the animated drop zones based on position
            // Use the edgeThreshold variable for consistent detection
            final isTopEdge = localPosition.dy < edgeThreshold;
            final isBottomEdge = localPosition.dy > size.height - edgeThreshold;

            // If we're in a locked drop zone but moved significantly away from the edge,
            // unlock it to allow deactivation
            if (_topDropZoneLocked && !isTopEdge && hasSignificantMovement) {
              _topDropZoneLocked = false;
              _updateEdgeDropZones(false, isTop: true);
            }

            if (_bottomDropZoneLocked &&
                !isBottomEdge &&
                hasSignificantMovement) {
              _bottomDropZoneLocked = false;
              _updateEdgeDropZones(false, isBottom: true);
            }

            // Activate/deactivate drop zones
            if (isTopEdge) {
              _updateEdgeDropZones(true, isTop: true, isBottom: false);
            } else if (isBottomEdge) {
              _updateEdgeDropZones(true, isTop: false, isBottom: true);
            } else if (!_topDropZoneLocked && !_bottomDropZoneLocked) {
              // Only hide if not locked and not at edges
              _updateEdgeDropZones(false, isTop: true, isBottom: true);
            }

            // Update the drop zone in state
            _updateDropZone(localPosition, size);

            // For "before" or "after", check if they're siblings or can be siblings
            if (_currentDropZone == "before" || _currentDropZone == "after") {
              // Don't accept drop on self
              if (dragged.id == widget.node.id) return false;

              // We can drop if they're siblings or can become siblings
              final parent =
                  widget.parent ?? nodeProvider.findParentNode(widget.node.id);
              return parent != null ||
                  (nodeProvider.rootNodes.contains(widget.node));
            }

            // For "inside", check if this would create a cycle
            if (dragged.id == widget.node.id) return false;

            // Prevent cyclic references
            if (nodeProvider.isDescendantOf(dragged, widget.node)) return false;

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
          // Use onAcceptWithDetails to handle the drop
          onAcceptWithDetails: (DragTargetDetails<Node> details) {
            final dragged = details.data;
            final nodeProvider =
                Provider.of<NodeProvider>(context, listen: false);

            // Debug print to see which zone is being used on drop
            print(
                'Dropping in zone: ${_currentDropZone == "before" ? "Place above" : _currentDropZone == "after" ? "Place below" : "Add as child"}');

            // Handle drop based on the current zone
            if (_currentDropZone == "before") {
              nodeProvider.insertNodeBefore(dragged, widget.node);
              setState(() {
                _isTargeted = false;
              });
              _resetDropZoneLocks();
              _showReorderFeedback(dragged, "above");
              return;
            } else if (_currentDropZone == "after") {
              nodeProvider.insertNodeAfter(dragged, widget.node);
              setState(() {
                _isTargeted = false;
              });
              _resetDropZoneLocks();
              _showReorderFeedback(dragged, "below");
              return;
            }

            // This is a parent-child operation - Auto-expand and add as last child
            Future.microtask(() {
              bool success =
                  nodeProvider.moveNodeToLastChild(dragged, widget.node);

              if (success) {
                _showReorderFeedback(dragged, "as child of");
              }

              // Reset target state
              setState(() {
                _isTargeted = false;
              });
              _resetDropZoneLocks();
            });
          },
          onLeave: (_) {
            // Reset target state when drag leaves
            Future.microtask(() {
              setState(() {
                _isTargeted = false;
              });
              // Reset all drop zone states when leaving the node completely
              _resetDropZoneLocks();
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

        // Animated bottom drop zone
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          height: _showBottomDropZone ? 48.0 : 0.0,
          margin: EdgeInsets.only(left: indent + 16, right: 16),
          child: _showBottomDropZone
              ? DragTarget<Node>(
                  builder: (context, candidateData, rejectedData) {
                    final isActive = candidateData.isNotEmpty;
                    return Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isActive || _bottomDropZoneLocked
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2)
                            : Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.15),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: isActive || _bottomDropZoneLocked ? 3 : 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isActive || _bottomDropZoneLocked
                            ? [
                                BoxShadow(
                                  color: Theme.of(context)
                                      .shadowColor
                                      .withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_downward,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Place below",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  onWillAccept: (dragged) {
                    if (dragged == null) return false;
                    if (dragged.id == widget.node.id) return false;
                    // Prevent cyclic references
                    if (nodeProvider.isDescendantOf(dragged, widget.node))
                      return false;
                    return true;
                  },
                  onAccept: (dragged) {
                    nodeProvider.insertNodeAfter(dragged, widget.node);
                    _resetDropZoneLocks();
                    _showReorderFeedback(dragged, "below");
                  },
                  onLeave: (_) {
                    _updateEdgeDropZones(false, isBottom: true);
                  },
                )
              : null,
        ),
      ],
    );
  }

  // Build a customized target overlay based on the drop zone
  Widget _buildTargetOverlay(BuildContext context, bool hasChildren) {
    final theme = Theme.of(context);

    // Different visual styles based on the drop zone
    Color backgroundColor;
    Color borderColor;
    Widget content;

    if (_currentDropZone == "before") {
      // Enhanced "Place above" styling
      backgroundColor = theme.colorScheme.primary.withOpacity(0.15);
      borderColor = theme.colorScheme.primary;
      content = Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_upward,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "Place above",
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      );
    } else if (_currentDropZone == "after") {
      // Enhanced "Place below" styling
      backgroundColor = theme.colorScheme.primary.withOpacity(0.15);
      borderColor = theme.colorScheme.primary;
      content = Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_downward,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "Place below",
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      // Central "add as child" styling
      backgroundColor = theme.colorScheme.secondary.withOpacity(0.15);
      borderColor = theme.colorScheme.secondary;
      content = Container(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                !_isExpanded && hasChildren
                    ? Icons.expand_more
                    : Icons.add_circle_outline,
                color: theme.colorScheme.secondary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                !_isExpanded && hasChildren
                    ? 'Auto-expand and add as child'
                    : hasChildren
                        ? 'Add as child'
                        : 'Drop here',
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: content,
      ),
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
          width: _isTargeted || dragging || _isHovering ? 2 : 1,
        ),
        boxShadow: dragging || _isHovering || _isTargeted
            ? [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
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
    // A node cannot be moved inside itself (direct cycle)
    if (dragged.id == target.id) return true;

    // A node cannot be moved inside any of its descendants (would create cycle)
    return provider.isDescendantOf(dragged, target);
  }
}
