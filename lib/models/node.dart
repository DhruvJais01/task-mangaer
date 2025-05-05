import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

part 'node.g.dart';

@HiveType(typeId: 0)
class Node extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? notes;

  @HiveField(3)
  List<String>? tags;

  @HiveField(4)
  List<Node> children;

  @HiveField(5)
  bool isExpanded;

  @HiveField(6)
  String? parentId;

  @HiveField(7)
  int depth;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime lastEditedAt;

  Node({
    String? id,
    required this.title,
    this.notes,
    List<String>? tags,
    List<Node>? children,
    this.isExpanded = true,
    this.parentId,
    this.depth = 0,
    DateTime? createdAt,
    DateTime? lastEditedAt,
  })  : id = id ?? const Uuid().v4(),
        tags = tags ?? [],
        children = children ?? [],
        createdAt = createdAt ?? DateTime.now(),
        lastEditedAt = lastEditedAt ?? DateTime.now();

  Node copyWith({
    String? id,
    String? title,
    String? notes,
    List<String>? tags,
    List<Node>? children,
    bool? isExpanded,
    String? parentId,
    int? depth,
    DateTime? createdAt,
    DateTime? lastEditedAt,
  }) {
    return Node(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      children: children ?? List.from(this.children),
      isExpanded: isExpanded ?? this.isExpanded,
      parentId: parentId ?? this.parentId,
      depth: depth ?? this.depth,
      createdAt: createdAt ?? this.createdAt,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'tags': tags,
      'parentId': parentId,
      'children': children.map((c) => c.toJson()).toList(),
      'isExpanded': isExpanded,
      'depth': depth,
      'createdAt': createdAt.toIso8601String(),
      'lastEditedAt': lastEditedAt.toIso8601String(),
    };
  }

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      id: json['id'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      parentId: json['parentId'] as String?,
      children: (json['children'] as List<dynamic>? ?? [])
          .map((child) => Node.fromJson(child as Map<String, dynamic>))
          .toList(),
      isExpanded: json['isExpanded'] ?? true,
      depth: json['depth'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastEditedAt: json['lastEditedAt'] != null
          ? DateTime.parse(json['lastEditedAt'] as String)
          : DateTime.now(),
    );
  }

  // Helper method to find a node by ID in the tree
  Node? findNodeById(String nodeId) {
    if (id == nodeId) {
      return this;
    }

    for (final child in children) {
      final result = child.findNodeById(nodeId);
      if (result != null) {
        return result;
      }
    }

    return null;
  }

  // Helper method to add a child node to this node
  void addChild(Node child) {
    child.parentId = id;
    child.depth = depth + 1;
    children.add(child);
  }

  // Helper method to remove a child node from this node
  bool removeChild(String childId) {
    final initialLength = children.length;
    children.removeWhere((child) => child.id == childId);
    return children.length != initialLength;
  }

  // Update the last edited timestamp
  void markEdited() {
    lastEditedAt = DateTime.now();
  }
}
