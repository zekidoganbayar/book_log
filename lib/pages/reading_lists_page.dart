import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReadingListsPage extends StatefulWidget {
  const ReadingListsPage({Key? key}) : super(key: key);

  @override
  _ReadingListsPageState createState() => _ReadingListsPageState();
}

class _ReadingListsPageState extends State<ReadingListsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _readingLists = [];

  // Reference to Firestore collection
  final CollectionReference _listsCollection =
  FirebaseFirestore.instance.collection('reading_lists');

  @override
  void initState() {
    super.initState();
    _fetchReadingLists();
  }

  Future<void> _fetchReadingLists() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Using snapshots for real-time updates
      _listsCollection.snapshots().listen((snapshot) {
        setState(() {
          _readingLists = snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'] ?? 'Untitled List',
              'description': data['description'] ?? '',
              'bookCount': data['bookCount'] ?? 0,
              'coverColors': data['coverColors'] != null
                  ? List<Color>.from(
                (data['coverColors'] as List).map(
                      (color) => Color(color),
                ),
              )
                  : [Colors.indigo, Colors.blue, Colors.lightBlue],
              'books': data['books'] ?? [],
              'createdAt': data['createdAt'],
              'updatedAt': data['updatedAt'],
            };
          }).toList();
          _isLoading = false;
        });
      }, onError: (error) {
        _handleError('Error fetching reading lists: $error');
      });
    } catch (e) {
      _handleError('Error setting up reading lists listener: $e');
    }
  }

  void _handleError(String message) {
    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _deleteReadingList(String listId) async {
    try {
      await _listsCollection.doc(listId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reading list deleted successfully'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting reading list: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Lists'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _readingLists.isEmpty
          ? _buildEmptyState()
          : _buildReadingListsGrid(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showCreateListDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.list_alt,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No Reading Lists Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first reading list',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _showCreateListDialog();
            },
            icon: const Icon(Icons.add),
            label: const Text('CREATE LIST'),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingListsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _readingLists.length,
      itemBuilder: (context, index) {
        final list = _readingLists[index];
        return _buildReadingListCard(list);
      },
    );
  }

  Widget _buildReadingListCard(Map<String, dynamic> list) {
    return GestureDetector(
      onTap: () {
        _navigateToListDetail(list);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stack of book covers
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  for (int i = 0; i < 3; i++)
                    Positioned(
                      top: 20 + (i * 10),
                      left: 20 + (i * 10),
                      right: 20 + ((3 - 1 - i) * 10),
                      bottom: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          color: list['coverColors'][i],
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // List info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      list['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${list['bookCount']} books",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      list['description'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToListDetail(Map<String, dynamic> list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReadingListDetailPage(listId: list['id']),
      ),
    );
  }

  void _showCreateListDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Reading List'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'List Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                _createReadingList(
                  nameController.text,
                  descriptionController.text,
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
  }

  Future<void> _createReadingList(String name, String description) async {
    try {
      // Generate random colors for the list cover
      final List<int> coverColorInts = [
        Colors.indigo.value,
        Colors.blue.value,
        Colors.lightBlue.value,
      ];

      // Create new reading list in Firestore
      await _listsCollection.add({
        'name': name,
        'description': description,
        'bookCount': 0,
        'books': [],
        'coverColors': coverColorInts,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reading list created'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating reading list: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class ReadingListDetailPage extends StatefulWidget {
  final String listId;

  const ReadingListDetailPage({
    Key? key,
    required this.listId,
  }) : super(key: key);

  @override
  _ReadingListDetailPageState createState() => _ReadingListDetailPageState();
}

class _ReadingListDetailPageState extends State<ReadingListDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic> _listData = {};
  List<Map<String, dynamic>> _books = [];

  // References to Firestore collections
  final CollectionReference _listsCollection =
  FirebaseFirestore.instance.collection('reading_lists');
  final CollectionReference _booksCollection =
  FirebaseFirestore.instance.collection('books');

  @override
  void initState() {
    super.initState();
    _fetchListData();
  }

  Future<void> _fetchListData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get the reading list document
      DocumentSnapshot listDoc = await _listsCollection.doc(widget.listId).get();

      if (!listDoc.exists) {
        _handleError('Reading list not found');
        return;
      }

      Map<String, dynamic> data = listDoc.data() as Map<String, dynamic>;

      // Initialize list data
      setState(() {
        _listData = {
          'id': listDoc.id,
          'name': data['name'] ?? 'Untitled List',
          'description': data['description'] ?? '',
          'bookCount': data['bookCount'] ?? 0,
          'coverColors': data['coverColors'] != null
              ? List<Color>.from(
            (data['coverColors'] as List).map(
                  (color) => Color(color),
            ),
          )
              : [Colors.indigo, Colors.blue, Colors.lightBlue],
          'books': data['books'] ?? [],
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],
        };
      });

      // Fetch books in the list
      await _fetchBooksInList();
    } catch (e) {
      _handleError('Error fetching list data: $e');
    }
  }

  Future<void> _fetchBooksInList() async {
    try {
      List<String> bookIds = List<String>.from(_listData['books'] ?? []);

      if (bookIds.isEmpty) {
        setState(() {
          _books = [];
          _isLoading = false;
        });
        return;
      }

      // Fetch each book document
      List<Map<String, dynamic>> books = [];
      for (String bookId in bookIds) {
        DocumentSnapshot bookDoc = await _booksCollection.doc(bookId).get();
        if (bookDoc.exists) {
          Map<String, dynamic> bookData = bookDoc.data() as Map<String, dynamic>;
          books.add({
            'id': bookDoc.id,
            'title': bookData['title'] ?? 'Untitled',
            'author': bookData['author'] ?? 'Unknown Author',
            'coverUrl': bookData['coverUrl'] ?? '',
            'status': bookData['status'] ?? 'To Read',
          });
        }
      }

      setState(() {
        _books = books;
        _isLoading = false;
      });
    } catch (e) {
      _handleError('Error fetching books in list: $e');
    }
  }

  void _handleError(String message) {
    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _editListDetails() async {
    final nameController = TextEditingController(text: _listData['name']);
    final descriptionController = TextEditingController(text: _listData['description']);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Reading List'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'List Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(null);
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.of(context).pop({
                  'name': nameController.text,
                  'description': descriptionController.text,
                });
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        // Update list in Firestore
        await _listsCollection.doc(widget.listId).update({
          'name': result['name'],
          'description': result['description'],
          'updatedAt': Timestamp.now(),
        });

        // Update local state
        setState(() {
          _listData['name'] = result['name'];
          _listData['description'] = result['description'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reading list updated'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating list: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteList() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reading List'),
        content: Text('Are you sure you want to delete "${_listData['name']}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _listsCollection.doc(widget.listId).delete();

        Navigator.of(context).pop(); // Return to reading lists page

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reading list deleted'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting list: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addBookToList() async {
    // Fetch all available books that aren't already in the list
    try {
      List<String> bookIds = List<String>.from(_listData['books'] ?? []);

      QuerySnapshot querySnapshot = await _booksCollection.get();

      List<Map<String, dynamic>> availableBooks = querySnapshot.docs
          .where((doc) => !bookIds.contains(doc.id))
          .map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Untitled',
          'author': data['author'] ?? 'Unknown Author',
        };
      })
          .toList();

      if (availableBooks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No more books available to add'),
          ),
        );
        return;
      }

      // Show dialog to select books
      final result = await showDialog<List<String>>(
        context: context,
        builder: (context) => AddBooksDialog(availableBooks: availableBooks),
      );

      if (result != null && result.isNotEmpty) {
        // Add selected books to the list
        List<String> updatedBookIds = [...bookIds, ...result];

        await _listsCollection.doc(widget.listId).update({
          'books': updatedBookIds,
          'bookCount': updatedBookIds.length,
          'updatedAt': Timestamp.now(),
        });

        setState(() {
          _listData['books'] = updatedBookIds;
          _listData['bookCount'] = updatedBookIds.length;
        });

        // Refresh books list
        await _fetchBooksInList();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.length} books added to list'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding books: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeBookFromList(String bookId, String bookTitle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Book'),
        content: Text('Remove "$bookTitle" from this reading list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        List<String> bookIds = List<String>.from(_listData['books']);
        bookIds.remove(bookId);

        await _listsCollection.doc(widget.listId).update({
          'books': bookIds,
          'bookCount': bookIds.length,
          'updatedAt': Timestamp.now(),
        });

        setState(() {
          _listData['books'] = bookIds;
          _listData['bookCount'] = bookIds.length;
          _books.removeWhere((book) => book['id'] == bookId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Book removed from list'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing book: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading ? 'Reading List' : _listData['name']),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _isLoading ? null : _editListDetails,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isLoading ? null : _deleteList,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // List header with description
          _buildListHeader(),
          // Books in list
          Expanded(
            child: _books.isEmpty
                ? _buildEmptyBooksList()
                : _buildBooksList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _addBookToList,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildListHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _listData['name'],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_listData['description']?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _listData['description'],
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              "${_listData['bookCount']} books",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBooksList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No Books In This List Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add books to this list',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _books.length,
      itemBuilder: (context, index) {
        final book = _books[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: ListTile(
            leading: Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: book['coverUrl'] != null && book['coverUrl'].isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  book['coverUrl'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.book),
                ),
              )
                  : const Icon(Icons.book),
            ),
            title: Text(book['title']),
            subtitle: Text(book['author']),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => _removeBookFromList(book['id'], book['title']),
            ),
            onTap: () {
              Navigator.pushNamed(
                context,
                '/book-detail',
                arguments: book,
              );
            },
          ),
        );
      },
    );
  }
}

class AddBooksDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableBooks;

  const AddBooksDialog({
    Key? key,
    required this.availableBooks,
  }) : super(key: key);

  @override
  _AddBooksDialogState createState() => _AddBooksDialogState();
}

class _AddBooksDialogState extends State<AddBooksDialog> {
  final Set<String> _selectedBookIds = {};
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredBooks {
    if (_searchQuery.isEmpty) {
      return widget.availableBooks;
    }
    final query = _searchQuery.toLowerCase();
    return widget.availableBooks.where((book) {
      return book['title'].toString().toLowerCase().contains(query) ||
          book['author'].toString().toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Books to List'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search books',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredBooks.isEmpty
                  ? const Center(
                child: Text('No books found'),
              )
                  : ListView.builder(
                itemCount: _filteredBooks.length,
                itemBuilder: (context, index) {
                  final book = _filteredBooks[index];
                  final isSelected = _selectedBookIds.contains(book['id']);

                  return CheckboxListTile(
                    title: Text(book['title']),
                    subtitle: Text(book['author']),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedBookIds.add(book['id']);
                        } else {
                          _selectedBookIds.remove(book['id']);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_selectedBookIds.toList());
          },
          child: Text('ADD ${_selectedBookIds.length} BOOKS'),
        ),
      ],
    );
  }
}