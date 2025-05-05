import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/node.dart';
import 'providers/node_provider.dart';
import 'widgets/notion_tree.dart';
import 'widgets/node_editor.dart';

void main() {
  runApp(const NotionDemoApp());
}

class NotionDemoApp extends StatelessWidget {
  const NotionDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => NodeProvider(),
      child: MaterialApp(
        title: 'Notion-like Tree Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const NotionDemoScreen(),
      ),
    );
  }
}

class NotionDemoScreen extends StatelessWidget {
  const NotionDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nodeProvider = Provider.of<NodeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notion-like Tree Demo'),
      ),
      body: NotionTree(
        rootNode: nodeProvider.rootNode,
        onNodeTap: (node) => _showNodeDetails(context, node),
        onAddChild: (node) => _showAddNodeDialog(context, node),
        onEdit: (node) => _showNodeDetails(context, node),
        onDelete: (node) => _confirmDelete(context, node),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddNodeDialog(context, nodeProvider.rootNode),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showNodeDetails(BuildContext context, Node node) {
    showDialog(
      context: context,
      builder: (context) => NodeEditor(
        isEditing: true,
        node: node,
      ),
    );
  }

  void _showAddNodeDialog(BuildContext context, Node parentNode) {
    showDialog(
      context: context,
      builder: (context) => NodeEditor(parentNode: parentNode),
    );
  }

  void _confirmDelete(BuildContext context, Node node) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${node.title}"?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () {
              final nodeProvider =
                  Provider.of<NodeProvider>(context, listen: false);
              nodeProvider.deleteNode(node.id);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
