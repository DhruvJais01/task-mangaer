import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node.dart';
import '../providers/node_provider.dart';
import '../widgets/node_tree.dart';
import '../widgets/node_editor.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _showSearchBar
            ? TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: Theme.of(context).appBarTheme.foregroundColor ??
                        Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                style: TextStyle(
                  color: Theme.of(context).appBarTheme.foregroundColor ??
                      Theme.of(context).colorScheme.onSurface,
                ),
                autofocus: true,
                onChanged: (value) {
                  Provider.of<NodeProvider>(context, listen: false)
                      .searchNodes(value);
                },
              )
            : const Text('Innovizia Task Manager'),
        centerTitle: !_showSearchBar,
        actions: [
          IconButton(
            icon: Icon(_showSearchBar ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_showSearchBar) {
                  _searchController.clear();
                  Provider.of<NodeProvider>(context, listen: false)
                      .clearSearch();
                }
                _showSearchBar = !_showSearchBar;
              });
            },
          ),
        ],
      ),
      body: Consumer<NodeProvider>(
        builder: (context, nodeProvider, _) {
          final isSearching = nodeProvider.isSearchActive;
          final nodes =
              isSearching ? nodeProvider.searchResults : nodeProvider.rootNodes;

          return Column(
            children: [
              Expanded(
                child: nodes.isEmpty
                    ? _buildEmptyState(context, isSearching)
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
          tooltip: 'Add Root Node',
          child: const Icon(Icons.add),
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
              isSearching ? 'No matching tasks found' : 'No tasks yet',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try a different search term'
                  : 'Tap the + button to add your first task',
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
