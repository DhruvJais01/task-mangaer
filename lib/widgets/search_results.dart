import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/node_provider.dart';
import 'node_editor.dart';

class SearchResults extends StatelessWidget {
  final List<Node> nodes;

  const SearchResults({super.key, required this.nodes});

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const Center(child: Text('No results found'));
    }

    return ListView.builder(
      itemCount: nodes.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final node = nodes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(node.title),
            subtitle:
                node.notes.isNotEmpty
                    ? Text(
                      node.notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                    : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (node.tags.isNotEmpty)
                  Chip(
                    label: Text(
                      '${node.tags.length} tags',
                      style: const TextStyle(fontSize: 12),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
            onTap: () => _showNodeDetails(context, node),
          ),
        );
      },
    );
  }

  void _showNodeDetails(BuildContext context, Node node) {
    final nodeProvider = Provider.of<NodeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => NodeEditor(isEditing: true, node: node),
    ).then((_) {
      // Clear search and go back to main tree after editing a node from search
      nodeProvider.clearSearch();
    });
  }
}
