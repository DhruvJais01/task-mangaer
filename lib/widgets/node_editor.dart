import 'package:flutter/material.dart';
import '../models/node.dart';

class NodeEditor extends StatefulWidget {
  final Node? node;
  final Node? parent;
  final void Function(Node) onSubmit;

  const NodeEditor({
    Key? key,
    this.node,
    this.parent,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<NodeEditor> createState() => _NodeEditorState();
}

class _NodeEditorState extends State<NodeEditor> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _tagsController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.node?.title ?? '');
    _notesController = TextEditingController(text: widget.node?.notes ?? '');
    _tagsController = TextEditingController(
      text: widget.node?.tags?.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final now = DateTime.now();

      // If creating a new node, set both dates to now
      if (widget.node == null) {
        final node = Node(
          title: _titleController.text.trim(),
          notes: _notesController.text.trim(),
          tags: tags,
          createdAt: now,
          lastEditedAt: now,
        );
        widget.onSubmit(node);
      } else {
        // If editing, update only lastEditedAt, preserve createdAt
        final node = widget.node!.copyWith(
          title: _titleController.text.trim(),
          notes: _notesController.text.trim(),
          tags: tags,
          lastEditedAt: now,
        );
        widget.onSubmit(node);
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.node == null ? 'Add Task' : 'Edit Task'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Title cannot be empty'
                    : null,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              if (widget.node != null || widget.parent != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.layers, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        widget.node != null
                            ? 'Current depth: ${widget.node!.depth + 1} of 5'
                            : 'Will be created at depth: ${(widget.parent?.depth ?? -1) + 2} of 5',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.node == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

Future<void> showNodeEditor({
  required BuildContext context,
  Node? node,
  Node? parent,
  required void Function(Node) onSubmit,
}) {
  return showDialog(
    context: context,
    builder: (context) =>
        NodeEditor(node: node, parent: parent, onSubmit: onSubmit),
  );
}
