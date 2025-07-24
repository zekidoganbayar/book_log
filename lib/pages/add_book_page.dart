import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddBookPage extends StatefulWidget {
  const AddBookPage({Key? key}) : super(key: key);

  @override
  _AddBookPageState createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pagesController = TextEditingController();
  final _publishedDateController = TextEditingController();

  String _selectedStatus = 'To Read';
  DateTime? _selectedPublishedDate;

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isManualEntry = true; // Changed to true to show manual entry form first

  // Reference to the books collection in Firestore
  final CollectionReference _booksCollection =
  FirebaseFirestore.instance.collection('books');

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _pagesController.dispose();
    _publishedDateController.dispose();
    super.dispose();
  }

  void _searchBooks(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Search in Firestore
      QuerySnapshot querySnapshot = await _booksCollection
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(10)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // Secondary search by author if no results by title
        querySnapshot = await _booksCollection
            .where('author', isGreaterThanOrEqualTo: query)
            .where('author', isLessThanOrEqualTo: query + '\uf8ff')
            .limit(10)
            .get();
      }

      setState(() {
        _searchResults = querySnapshot.docs
            .map((doc) => {
          'id': doc.id,
          'title': (doc.data() as Map<String, dynamic>)['title'] ?? '',
          'author': (doc.data() as Map<String, dynamic>)['author'] ?? '',
        })
            .toList();
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching books: $e')),
      );
    }
  }

  void _selectBook(String bookId) async {
    setState(() {
      _isSearching = true;
    });

    try {
      // Get the book details from Firestore
      DocumentSnapshot bookDoc = await _booksCollection.doc(bookId).get();

      if (bookDoc.exists) {
        Map<String, dynamic> bookData = bookDoc.data() as Map<String, dynamic>;

        setState(() {
          _titleController.text = bookData['title'] ?? '';
          _authorController.text = bookData['author'] ?? '';
          _descriptionController.text = bookData['description'] ?? '';
          _pagesController.text = bookData['pages']?.toString() ?? '';

          // Handle date conversion
          if (bookData['publishedDate'] != null) {
            Timestamp timestamp = bookData['publishedDate'];
            _selectedPublishedDate = timestamp.toDate();
            _publishedDateController.text = "${_selectedPublishedDate!.year}-${_selectedPublishedDate!.month.toString().padLeft(2, '0')}-${_selectedPublishedDate!.day.toString().padLeft(2, '0')}";
          }

          _selectedStatus = bookData['status'] ?? 'To Read';
          _searchResults = [];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading book details: $e')),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _addBook() async {
    if (_formKey.currentState!.validate()) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Prepare book data
        Map<String, dynamic> bookData = {
          'title': _titleController.text,
          'author': _authorController.text,
          'description': _descriptionController.text,
          'pages': _pagesController.text.isNotEmpty
              ? int.parse(_pagesController.text)
              : null,
          'publishedDate': _selectedPublishedDate != null
              ? Timestamp.fromDate(_selectedPublishedDate!)
              : null,
          'status': _selectedStatus,
          'addedAt': Timestamp.now(),
          'lastUpdated': Timestamp.now(),
        };

        // Add to Firestore
        await _booksCollection.add(bookData);

        // Close loading dialog
        Navigator.pop(context);

        // Show success message and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Book added to your collection'),
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        // Close loading dialog
        Navigator.pop(context);

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding book: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedPublishedDate ?? DateTime.now(),
      firstDate: DateTime(1800),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedPublishedDate) {
      setState(() {
        _selectedPublishedDate = picked;
        _publishedDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Book'),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Manual entry form - now shown first
              if (_isManualEntry || _titleController.text.isNotEmpty)
                _buildManualEntryForm(),

              // Search section - now shown second
              if (!_isManualEntry) _buildSearchSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search field
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search for a book',
            hintText: 'Enter title, author, or ISBN',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: _searchBooks,
        ),

        // Loading indicator
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),

        // Search results
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('${_searchResults[index]['title']} by ${_searchResults[index]['author']}'),
                  onTap: () => _selectBook(_searchResults[index]['id']),
                );
              },
            ),
          ),

        // No results message
        if (_searchResults.isEmpty && _isSearching == false)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Search for books by title, author, or ISBN',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildManualEntryForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          const SizedBox(height: 24),

          // Title field
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Book Title *',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter the book title';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Author field
          TextFormField(
            controller: _authorController,
            decoration: const InputDecoration(
              labelText: 'Author *',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter the author name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Description field
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // Pages field
          TextFormField(
            controller: _pagesController,
            decoration: const InputDecoration(
              labelText: 'Number of Pages',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          // Published date field
          TextFormField(
            controller: _publishedDateController,
            decoration: InputDecoration(
              labelText: 'Publication Date',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _selectDate(context),
              ),
            ),
            readOnly: true,
            onTap: () => _selectDate(context),
          ),
          const SizedBox(height: 24),

          // Reading status
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reading Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'Reading',
                    label: Text('Reading'),
                    icon: Icon(Icons.auto_stories),
                  ),
                  ButtonSegment<String>(
                    value: 'Completed',
                    label: Text('Completed'),
                    icon: Icon(Icons.done),
                  ),
                  ButtonSegment<String>(
                    value: 'To Read',
                    label: Text('To Read'),
                    icon: Icon(Icons.bookmark),
                  ),
                ],
                selected: {_selectedStatus},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _selectedStatus = newSelection.first;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Add book button
          ElevatedButton.icon(
            onPressed: _addBook,
            icon: const Icon(Icons.add),
            label: const Text('ADD TO MY BOOKS'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ],
      ),
    );
  }
}