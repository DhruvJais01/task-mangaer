import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/node.dart';
import 'package:uuid/uuid.dart';

class NodeProvider extends ChangeNotifier {
  late Box<Node> _nodesBox;
  String _searchQuery = '';
  List<Node> _searchResults = [];
  List<Node> rootNodes = [];

  NodeProvider() {
    _initHive();
    // Initialize with a sample root node if no data
    if (rootNodes.isEmpty) {
      rootNodes = [
        Node(
          id: '1',
          title: 'Welcome',
          depth: 0,
          children: [
            Node(
              id: '2',
              title: 'Level 1 - Task A',
              depth: 1,
              children: [
                Node(
                  id: '3',
                  title: 'Level 2 - Subtask A1',
                  depth: 2,
                  children: [
                    Node(
                      id: '4',
                      title: 'Level 3 - Subtask A1.1',
                      depth: 3,
                      children: [
                        Node(
                          id: '5',
                          title: 'Level 4 - Subtask A1.1.1',
                          depth: 4,
                          children: [],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ];
    }
  }

  // Getters
  String get searchQuery => _searchQuery;
  List<Node> get searchResults => _searchResults;
  bool get isSearchActive => _searchQuery.isNotEmpty;

  // Initialize Hive and load data
  Future<void> _initHive() async {
    try {
      _nodesBox = Hive.box<Node>('nodes');

      if (_nodesBox.isEmpty) {
        // Create default root nodes if box is empty
        final defaultRoot = Node(
          title: 'Getting Started',
          notes: 'Welcome to Hierarchical List Creator!',
          children: [
            Node(title: 'Add items using the + button'),
            Node(title: 'Drag items to reorder or nest them'),
            Node(title: 'Tap an item to edit its details'),
          ],
        );
        rootNodes = [defaultRoot];
        await saveNodes();
      } else {
        // Load from Hive
        final List<dynamic> storedNodes = _nodesBox.values.toList();
        rootNodes = storedNodes.map((node) => node as Node).toList();
      }
    } catch (e) {
      debugPrint('Error initializing Hive: $e');
      // Fallback to sample data if Hive fails
    }

    notifyListeners();
  }

  // Save all nodes
  Future<void> saveNodes() async {
    try {
      // Clear existing data
      await _nodesBox.clear();

      // Save all root nodes
      for (int i = 0; i < rootNodes.length; i++) {
        await _nodesBox.put(i.toString(), rootNodes[i]);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error saving nodes: $e');
    }
  }

  // Add a new node
  void addNode(Node parentNode, Node newNode) {
    final parent = findNodeById(parentNode.id);
    if (parent != null) {
      parent.addChild(newNode);
      saveNodes();
    }
  }

  // Update an existing node
  void updateNode(
    String nodeId, {
    String? title,
    String? notes,
    List<String>? tags,
  }) {
    final node = findNodeById(nodeId);
    if (node != null) {
      if (title != null) node.title = title;
      if (notes != null) node.notes = notes;
      if (tags != null) node.tags = tags;
      saveNodes();
    }
  }

  // Delete a node
  void deleteNode(String nodeId) {
    // First check if it's a root node
    final rootIndex = rootNodes.indexWhere((node) => node.id == nodeId);
    if (rootIndex != -1) {
      rootNodes.removeAt(rootIndex);
      saveNodes();
      return;
    }

    // Otherwise, find its parent and remove it
    for (final root in rootNodes) {
      if (_removeNodeFromTreeRecursive(root, nodeId)) {
        saveNodes();
        return;
      }
    }
  }

  // Helper method for recursive node removal
  bool _removeNodeFromTreeRecursive(Node parent, String nodeId) {
    // Check direct children
    final directChildIndex =
        parent.children.indexWhere((child) => child.id == nodeId);
    if (directChildIndex != -1) {
      parent.children.removeAt(directChildIndex);
      return true;
    }

    // Check children of children
    for (final child in parent.children) {
      if (_removeNodeFromTreeRecursive(child, nodeId)) {
        return true;
      }
    }

    return false;
  }

  // Toggle node expansion
  void toggleNodeExpansion(String nodeId) {
    final node = findNodeById(nodeId);
    if (node != null) {
      node.isExpanded = !node.isExpanded;
      saveNodes();
    }
  }

  // Move a node to a new parent
  void moveNode(String nodeId, String newParentId) {
    // Don't allow moving a node to itself
    if (nodeId == newParentId) return;

    // Find the nodes
    final Node? targetNode = findNodeById(nodeId);
    if (targetNode == null) return;

    final Node? newParent = findNodeById(newParentId);
    if (newParent == null) return;

    // Check if newParent is a child of the node we're moving (would create a cycle)
    if (_wouldCreateCycle(targetNode, newParent)) return;

    // Check depth limit
    if (newParent.depth + 1 + _getMaxDepth(targetNode) > 5) return;

    // Remove from current parent
    deleteNode(nodeId);

    // Add to new parent
    newParent.addChild(targetNode);

    // Update depth
    _updateDepthRecursively(targetNode, newParent.depth + 1);

    saveNodes();
  }

  // Check if moving would create a cycle
  bool _wouldCreateCycle(Node node, Node possibleDescendant) {
    if (node.id == possibleDescendant.id) return true;

    Node? current = findParentNode(possibleDescendant.id);
    while (current != null) {
      if (current.id == node.id) return true;
      current = findParentNode(current.id);
    }

    return false;
  }

  // Reorder nodes within the same parent
  void reorderNodes(String parentId, int oldIndex, int newIndex) {
    // Handle root level reordering
    if (parentId == 'root') {
      if (rootNodes.length < 2) return;

      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final item = rootNodes.removeAt(oldIndex);
      rootNodes.insert(newIndex, item);
      saveNodes();
      return;
    }

    // Handle child level reordering
    final parent = findNodeById(parentId);
    if (parent == null || parent.children.length < 2) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = parent.children.removeAt(oldIndex);
    parent.children.insert(newIndex, item);
    saveNodes();
  }

  // Search nodes by title
  void searchNodes(String query) {
    _searchQuery = query.trim();
    _searchResults = [];

    if (_searchQuery.isNotEmpty) {
      // Search in all root nodes
      for (final root in rootNodes) {
        _searchNodeAndChildren(root, _searchQuery.toLowerCase());
      }
    }

    notifyListeners();
  }

  // Helper to search a node and its children
  void _searchNodeAndChildren(Node node, String query) {
    if (node.title.toLowerCase().contains(query)) {
      _searchResults.add(node);
    }

    for (final child in node.children) {
      _searchNodeAndChildren(child, query);
    }
  }

  // Clear search
  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    notifyListeners();
  }

  // Helper method to find a node by ID
  Node? findNodeById(String id) {
    // First check in rootNodes
    for (final root in rootNodes) {
      if (root.id == id) return root;
      final found = _findNodeInChildren(root, id);
      if (found != null) return found;
    }
    return null;
  }

  // Helper to recursively find a node
  Node? _findNodeInChildren(Node parent, String id) {
    for (final child in parent.children) {
      if (child.id == id) return child;
      final found = _findNodeInChildren(child, id);
      if (found != null) return found;
    }
    return null;
  }

  // Helper method to find a parent of a node
  Node? findParentNode(String childId) {
    for (final root in rootNodes) {
      final parent = _findParentRecursive(root, childId);
      if (parent != null) return parent;
    }
    return null;
  }

  // Helper for recursive parent finding
  Node? _findParentRecursive(Node current, String childId) {
    for (final child in current.children) {
      if (child.id == childId) {
        return current;
      }

      final result = _findParentRecursive(child, childId);
      if (result != null) {
        return result;
      }
    }

    return null;
  }

  // Export nodes to JSON
  String exportToJson() {
    final List<Map<String, dynamic>> jsonList =
        rootNodes.map((node) => node.toJson()).toList();
    return jsonEncode(jsonList);
  }

  // Import nodes from JSON
  Future<void> importFromJson(String jsonString) async {
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      rootNodes = jsonList
          .map((item) => Node.fromJson(item as Map<String, dynamic>))
          .toList();
      await saveNodes();
      notifyListeners();
    } catch (e) {
      debugPrint('Error importing JSON: $e');
      rethrow;
    }
  }

  // Add a new child node to a parent
  void addNodeToProvider({
    required Node parent,
    String title = 'New Node',
    String? notes,
    List<String>? tags,
  }) {
    if (parent.depth >= 4) return; // Prevent adding at depth 5+

    final now = DateTime.now();
    final newNode = Node(
      id: const Uuid().v4(),
      title: title,
      notes: notes,
      tags: tags,
      depth: parent.depth + 1,
      parentId: parent.id,
      children: [],
      createdAt: now,
      lastEditedAt: now,
    );

    parent.children.add(newNode);
    notifyListeners();
  }

  // Edit a node's title, notes, tags, etc.
  void editNode(Node updated) {
    Node? node = findNodeById(updated.id);
    if (node != null) {
      node.title = updated.title;
      node.notes = updated.notes;
      node.tags = updated.tags;
      node.lastEditedAt = DateTime.now(); // Update the edit timestamp
      notifyListeners();
    }
  }

  // Delete a node from the tree
  void deleteNodeFromProvider(Node node) {
    // First check if it's a root node
    int rootIndex = rootNodes.indexWhere((n) => n.id == node.id);
    if (rootIndex != -1) {
      rootNodes.removeAt(rootIndex);
      notifyListeners();
      return;
    }

    // Otherwise find the parent and remove
    for (final root in rootNodes) {
      if (_removeNodeFromTree(root, node.id)) {
        notifyListeners();
        return;
      }
    }
  }

  // Remove a node from the tree by id (returns true if removed)
  bool _removeNodeFromTree(Node current, String nodeId) {
    for (final child in current.children) {
      if (child.id == nodeId) {
        current.children.remove(child);
        return true;
      }
      if (_removeNodeFromTree(child, nodeId)) return true;
    }
    return false;
  }

  // Move a node to become a child of another node
  bool moveNodeToProvider({
    required Node dragged,
    required Node target,
    required String position, // Only 'inside' is supported
  }) {
    // Prevent moving into itself or its descendants
    if (dragged.id == target.id || _wouldCreateCycle(dragged, target)) {
      return false;
    }

    // Calculate new depth as child of target
    final int newDepth = target.depth + 1;

    // Check if this would exceed max depth
    final maxChildDepth = getMaxDepth(dragged);
    if (newDepth + maxChildDepth > 5) {
      return false;
    }

    // First, remove the node from its current position
    // Remove from rootNodes if it's there
    final wasInRoot = rootNodes.any((n) => n.id == dragged.id);
    if (wasInRoot) {
      rootNodes.removeWhere((n) => n.id == dragged.id);
    } else {
      // Otherwise find and remove it from its parent
      final oldParent = findParentNode(dragged.id);
      if (oldParent != null) {
        oldParent.children.removeWhere((child) => child.id == dragged.id);
      }
    }

    // Update depth for the dragged node and all its children
    _updateDepthRecursively(dragged, newDepth);

    // Add as child to target
    dragged.parentId = target.id;
    target.children.add(dragged);

    // Make sure target is expanded to show the new child
    target.isExpanded = true;

    // Save changes and update UI
    saveNodes();
    notifyListeners();
    return true;
  }

  // Recursively update depth for node and its children
  void _updateDepthRecursively(Node node, int newDepth) {
    node.depth = newDepth;
    for (final child in node.children) {
      _updateDepthRecursively(child, newDepth + 1);
    }
  }

  // Get the max depth of a node's subtree (0 if no children)
  int _getMaxDepth(Node node) {
    if (node.children.isEmpty) return 0;
    return 1 + node.children.map(_getMaxDepth).fold(0, (a, b) => a > b ? a : b);
  }

  // Public wrapper for max depth
  int getMaxDepth(Node node) => _getMaxDepth(node);

  // Add a new node to the root level
  void addRootNode(Node node) {
    final now = DateTime.now();
    // If this is a fresh node (e.g., from NodeEditor), set timestamps
    // If it's an existing node, preserve its timestamps
    if (node.createdAt == node.lastEditedAt) {
      node = node.copyWith(
          depth: 0, parentId: null, createdAt: now, lastEditedAt: now);
    } else {
      node = node.copyWith(depth: 0, parentId: null);
    }
    rootNodes.add(node);
    notifyListeners();
  }
}
