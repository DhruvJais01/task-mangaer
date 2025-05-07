import 'package:flutter/material.dart';
import '../models/node.dart';
import 'node_item.dart';

class NodeTree extends StatelessWidget {
  final List<Node> nodes;
  final Node? parent;
  final Function(Node) onEdit;
  final Function(Node) onDelete;

  const NodeTree({
    super.key,
    required this.nodes,
    this.parent,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Render each node in the list
        ...nodes.map((node) => NodeItem(
              node: node,
              parent: parent,
              onEdit: onEdit,
              onDelete: onDelete,
            )),
      ],
    );
  }
}
