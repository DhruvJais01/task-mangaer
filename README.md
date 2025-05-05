# Hierarchical List Creator

A Flutter application that allows you to create and manage hierarchical lists with nesting up to 5 levels deep.

## Features

- **Create/Edit/Delete nodes:** Add, modify, or remove nodes at any level
- **Drag-and-Drop:** Intuitively organize your lists by dragging nodes
- **Nesting Limit:** Maximum depth of 5 levels (enforced during drag operations)
- **Expand/Collapse:** Toggle visibility of child nodes
- **Search:** Filter nodes by title
- **Notes & Tags:** Add additional information to each node
- **Persistent Storage:** Data is saved locally using Hive
- **Light/Dark Mode:** Automatically adapts to system theme

## Running the App

1. Make sure you have Flutter installed and set up (Flutter 3.0+ recommended)
2. Clone this repository
3. Install dependencies:
   ```
   flutter pub get
   ```
4. Generate Hive adapters:
   ```
   flutter packages pub run build_runner build --delete-conflicting-outputs
   ```
5. Run the app:
   ```
   flutter run
   ```

## Usage

- Tap the "+" button to add a root node
- Long-press a node to start dragging it
- Drag a node to:
  - Above/below another node (sibling position)
  - Inside another node (child position)
- The app will prevent nesting deeper than 5 levels
- Tap the edit icon to modify a node
- Tap the delete icon to remove a node

## Architecture

- **Model:** `Node` class with support for hierarchical structure
- **Provider:** `NodeProvider` for state management
- **UI Components:** Modular widgets for tree rendering and item display
- **Persistence:** Hive database for local storage

## Requirements

- Flutter 3.0.0 or higher
- Dart 2.17.0 or higher

## Technical Details

### Architecture

- **State Management**: Provider pattern
- **Data Persistence**: Hive (NoSQL local database)
- **UI Components**: Custom Flutter widgets with Material Design

### Project Structure

- `lib/models`: Data models for nodes and related entities
- `lib/providers`: State management logic
- `lib/screens`: Main application screens
- `lib/widgets`: Reusable UI components
- `lib/main.dart`: Application entry point

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter Team for the amazing cross-platform framework
- Drag-and-drop lists package contributors
