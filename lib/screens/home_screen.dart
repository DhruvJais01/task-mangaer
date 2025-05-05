import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/node_provider.dart';
import '../widgets/node_tree.dart';
import '../widgets/node_editor.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inovizia Task Manager'),
        centerTitle: true,
      ),
      body: Consumer<NodeProvider>(
        builder: (context, nodeProvider, _) {
          final nodes = nodeProvider.rootNodes;

          return Column(
            children: [
              Expanded(
                child: nodes.isEmpty
                    ? _buildEmptyState(context, false)
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: NodeTree(
                            nodes: nodes,
                            onEdit: (node) {
                              showNodeEditor(
                                context: context,
                                node: node,
                                parent: null,
                                onSubmit: (updatedNode) {
                                  nodeProvider.editNode(updatedNode);
                                },
                              );
                            },
                            onDelete: (node) {
                              _confirmDelete(context, node, nodeProvider);
                            },
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<NodeProvider>(
        builder: (context, nodeProvider, _) => FloatingActionButton(
          onPressed: () {
            showNodeEditor(
              context: context,
              node: null,
              parent: null,
              onSubmit: (newNode) {
                nodeProvider.addRootNode(newNode);
              },
            );
          },
          child: const Icon(Icons.add),
          tooltip: 'Add Root Node',
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isSearching) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.note_add,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'No matching nodes found' : 'No nodes yet',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try a different search term'
                  : 'Tap the + button to add your first node',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Node node, NodeProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Node'),
        content: Text('Are you sure you want to delete "${node.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteNodeFromProvider(node);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
