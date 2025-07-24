import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookDetailPage extends StatefulWidget {
  const BookDetailPage({Key? key}) : super(key: key);

  @override
  _BookDetailPageState createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  String _status = 'Reading';
  int _rating = 0;
  int _progress = 0;
  bool _isLoading = false;
  bool _isSaving = false;
  final TextEditingController _noteController = TextEditingController();
  late String bookId;
  Map<String, dynamic> bookData = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get the book ID from the route arguments
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('id')) {
      bookId = args['id'];
      _fetchBookDetails();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get the book details from Firestore
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('books')
          .doc(bookId)
          .get();

      if (docSnapshot.exists) {
        setState(() {
          bookData = docSnapshot.data() as Map<String, dynamic>;
          _status = bookData['status'] ?? 'Reading';
          _rating = bookData['rating'] ?? 0;
          _progress = bookData['progress'] ?? 0;
          _noteController.text = bookData['notes'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book not found')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading book details: $e')),
      );
    }
  }

  Future<void> _updateBookStatus() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('books').doc(bookId).update({
        'status': _status,
        'lastUpdated': Timestamp.now(),
      });

      // If status is Completed and there is no completedDate yet, add it
      if (_status == 'Completed' && !bookData.containsKey('completedDate')) {
        await FirebaseFirestore.instance.collection('books').doc(bookId).update({
          'completedDate': Timestamp.now(),
        });
      }

      setState(() {
        bookData['status'] = _status;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status updated')),
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  Future<void> _updateBookProgress() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('books').doc(bookId).update({
        'progress': _progress,
        'lastUpdated': Timestamp.now(),
      });

      setState(() {
        bookData['progress'] = _progress;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress updated')),
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating progress: $e')),
      );
    }
  }

  Future<void> _updateBookRating() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('books').doc(bookId).update({
        'rating': _rating,
        'lastUpdated': Timestamp.now(),
      });

      setState(() {
        bookData['rating'] = _rating;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating updated')),
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating rating: $e')),
      );
    }
  }

  Future<void> _saveNotes() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('books').doc(bookId).update({
        'notes': _noteController.text,
        'lastUpdated': Timestamp.now(),
      });

      setState(() {
        bookData['notes'] = _noteController.text;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes saved')),
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving notes: $e')),
      );
    }
  }

  Future<void> _logReadingSession() async {
    try {
      // Get the current timestamp
      Timestamp now = Timestamp.now();

      // Create a reading session document
      await FirebaseFirestore.instance.collection('reading_sessions').add({
        'bookId': bookId,
        'bookTitle': bookData['title'],
        'date': now,
        'progress': _progress,
      });

      // Update book's last read date
      await FirebaseFirestore.instance.collection('books').doc(bookId).update({
        'lastReadDate': now,
        'lastUpdated': now,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reading session logged')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging reading session: $e')),
      );
    }
  }

  Future<void> _deleteBook() async {
    try {
      await FirebaseFirestore.instance.collection('books').doc(bookId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Book deleted')),
      );
      // Navigate to home page using named route
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
            (route) => false, // This removes all routes
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting book: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Book Details'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _showDeleteConfirmation(context);
            },
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Book cover and basic info
            _buildBookHeader(),
            // Book details
            _buildBookDetails(),
            // Reading status
            _buildReadingStatus(),
            // Reading progress
            if (_status == 'Reading') _buildReadingProgress(),
            // Rating
            if (_status == 'Completed') _buildRating(),
            // Notes section
            _buildNotesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildBookHeader() {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book cover
          Container(
            width: 120,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: bookData['coverUrl'] != null && bookData['coverUrl'].toString().isNotEmpty
                ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                bookData['coverUrl'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      Icons.book,
                      size: 50,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
            )
                : Center(
              child: Icon(
                Icons.book,
                size: 50,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Book info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookData['title'] ?? 'Untitled',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${bookData['author'] ?? 'Unknown Author'}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_status),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    _status,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (bookData['pages'] != null)
                  Text(
                    '${bookData['pages']} pages',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                if (bookData['publishedDate'] != null)
                  Text(
                    'Published: ${_formatDate(bookData['publishedDate'])}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookDetails() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bookData['description'] ?? 'No description available.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Reading Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildReadingInfo(),
        ],
      ),
    );
  }

  Widget _buildReadingInfo() {
    return Column(
      children: [
        if (bookData['startDate'] != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.calendar_today,
              color: Theme.of(context).primaryColor,
            ),
            title: const Text('Started Reading'),
            subtitle: Text(_formatDate(bookData['startDate'])),
          ),
        if (bookData['lastReadDate'] != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.access_time,
              color: Theme.of(context).primaryColor,
            ),
            title: const Text('Last Read'),
            subtitle: Text(_formatDate(bookData['lastReadDate'])),
          ),
        if (_status == 'Completed' && bookData['completedDate'] != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.done_all,
              color: Theme.of(context).primaryColor,
            ),
            title: const Text('Completed'),
            subtitle: Text(_formatDate(bookData['completedDate'])),
          ),
      ],
    );
  }

  Widget _buildReadingStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reading Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
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
            selected: {_status},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _status = newSelection.first;
              });
              _updateBookStatus();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReadingProgress() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Reading Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$_progress%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderWithRoundedValues(
            min: 0,
            max: 100,
            divisions: 20,
            value: _progress.toDouble(),
            onChanged: (newValue) {
              setState(() {
                _progress = newValue.round();
              });
            },
            onChangeEnd: (newValue) {
              _updateBookProgress();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRating() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Rating',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  size: 32,
                  color: Colors.blue,
                ),
                onPressed: () {
                  setState(() {
                    _rating = index + 1;
                  });
                  _updateBookRating();
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              hintText: 'Add your notes here...',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _saveNotes,
            icon: const Icon(Icons.save),
            label: const Text('Save Notes'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 45),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Book'),
          content: const Text('Are you sure you want to delete this book from your collection?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteBook();
              },
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );
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

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      DateTime dateTime = date.toDate();
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
    return date.toString();
  }
}

// Custom slider with rounded values
class SliderWithRoundedValues extends StatelessWidget {
  final double min;
  final double max;
  final int divisions;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const SliderWithRoundedValues({
    Key? key,
    required this.min,
    required this.max,
    required this.divisions,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Theme.of(context).primaryColor,
            inactiveTrackColor: Colors.grey[300],
            trackHeight: 8.0,
            thumbColor: Theme.of(context).primaryColor,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0),
            overlayColor: Theme.of(context).primaryColor.withAlpha(32),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
          ),
          child: Slider(
            min: min,
            max: max,
            divisions: divisions,
            value: value,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(min.round().toString()),
            Text(max.round().toString()),
          ],
        ),
      ],
    );
  }
}