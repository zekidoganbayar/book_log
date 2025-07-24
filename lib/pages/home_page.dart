import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _books = [];

  // Reference to the books collection in Firestore
  final CollectionReference _booksCollection =
  FirebaseFirestore.instance.collection('books');

  @override
  void initState() {
    super.initState();
    _fetchBooks();
  }

  Future<void> _fetchBooks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Listen to real-time updates
      _booksCollection.snapshots().listen((snapshot) {
        setState(() {
          _books = snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'title': data['title'] ?? 'Untitled',
              'author': data['author'] ?? 'Unknown Author',
              'coverUrl': data['coverUrl'] ?? '',
              'status': data['status'] ?? 'To Read',
              'rating': data['rating'] ?? 0,
              'progress': data['progress'] ?? 0,
              'description': data['description'],
              'pages': data['pages'],
              'publishedDate': data['publishedDate'],
              'addedAt': data['addedAt'],
              'lastUpdated': data['lastUpdated'],
            };
          }).toList();
          _isLoading = false;
        });
      }, onError: (error) {
        _handleError('Error fetching books: $error');
      });
    } catch (e) {
      _handleError('Error setting up books listener: $e');
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

  Future<void> _deleteBook(String bookId) async {
    try {
      await _booksCollection.doc(bookId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Book deleted successfully'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting book: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredBooks {
    final status = ['Reading', 'Completed', 'To Read'][_selectedIndex];
    if (_selectedIndex == 3) {
      return _books;
    }
    return _books.where((book) => book['status'] == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Books'),
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _filteredBooks.isEmpty
                ? _buildEmptyState()
                : _buildBooksList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add-book').then((_) {
            // Refresh books when returning from add book page
            // (No longer needed with real-time listener, but kept for safety)
            _fetchBooks();
          });
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
            // Already on home
              break;
            case 1:
              Navigator.pushNamed(context, '/reading-stats');
              break;
            case 2:
              Navigator.pushNamed(context, '/reading-lists');
              break;
            case 3:
              Navigator.pushNamed(context, '/profile');
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Lists',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.menu_book, size: 30),
                ),
                SizedBox(height: 10),
                Text(
                  'Book Log',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Welcome to your journey!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('My Books'),
            selected: true,
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Reading Stats'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/reading-stats');
            },
          ),
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Reading Lists'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/reading-lists');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Exit'),
            onTap: () {
              // Exit the application
              SystemNavigator.pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(0, 'Reading'),
          ),
          Expanded(
            child: _buildTabItem(1, 'Completed'),
          ),
          Expanded(
            child: _buildTabItem(2, 'To Read'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Theme.of(context).primaryColor : Colors.black54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final status = ['Reading', 'Completed', 'To Read', 'Books'][_selectedIndex];
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
          Text(
            'No $status Books Yet',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first book',
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
      itemCount: _filteredBooks.length,
      itemBuilder: (context, index) {
        final book = _filteredBooks[index];
        return Dismissible(
          key: Key(book['id']),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
            ),
          ),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Delete Book'),
                  content: Text('Are you sure you want to delete "${book['title']}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('DELETE'),
                    ),
                  ],
                );
              },
            );
          },
          onDismissed: (direction) {
            _deleteBook(book['id']);
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/book-detail',
                  arguments: book,
                ).then((_) {
                  // Refresh books when returning from book detail
                  // (No longer needed with real-time listener, but kept for safety)
                  _fetchBooks();
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Book cover
                  Container(
                    width: 100,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                      ),
                    ),
                    child: book['coverUrl'] != null && book['coverUrl'].isNotEmpty
                        ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                      ),
                      child: Image.network(
                        book['coverUrl'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.book,
                              size: 40,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                      ),
                    )
                        : Center(
                      child: Icon(
                        Icons.book,
                        size: 40,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  // Book details
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            book['title'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Author
                          Text(
                            'by ${book['author']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Status
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(book['status']),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              book['status'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Progress or rating
                          if (book['status'] == 'Reading')
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${book['progress']}% completed',
                                  style: const TextStyle(
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: (book['progress'] ?? 0) / 100,
                                    backgroundColor: Colors.grey[200],
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            )
                          else if (book['status'] == 'Completed')
                            Row(
                              children: List.generate(5, (i) {
                                return Icon(
                                  i < (book['rating'] ?? 0) ? Icons.star : Icons.star_border,
                                  color: Colors.blue,
                                  size: 18,
                                );
                              }),
                            ),

                          // Show timestamps if available
                          if (book['addedAt'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Added: ${_formatTimestamp(book['addedAt'])}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Reading':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      case 'To Read':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}