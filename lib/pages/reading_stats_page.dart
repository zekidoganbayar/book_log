import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReadingStatsPage extends StatefulWidget {
  const ReadingStatsPage({Key? key}) : super(key: key);

  @override
  _ReadingStatsPageState createState() => _ReadingStatsPageState();
}

class _ReadingStatsPageState extends State<ReadingStatsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedTimeframe = 'This Month';
  bool _isLoading = true;

  // Data structures to hold our Firebase data
  Map<String, dynamic> _readingStats = {};
  List<Map<String, dynamic>> _readingHistory = [];
  List<Map<String, dynamic>> _monthlyData = [];
  Map<String, dynamic> _readingGoals = {};
  List<Map<String, dynamic>> _genreData = [];
  List<Map<String, dynamic>> _books = [];

  // Firestore references
  final CollectionReference _statsCollection = FirebaseFirestore.instance.collection('reading_stats');
  final CollectionReference _historyCollection = FirebaseFirestore.instance.collection('reading_history');
  final CollectionReference _goalCollection = FirebaseFirestore.instance.collection('reading_goals');
  final CollectionReference _genreCollection = FirebaseFirestore.instance.collection('genres');
  final CollectionReference _monthlyCollection = FirebaseFirestore.instance.collection('monthly_stats');
  final CollectionReference _booksCollection = FirebaseFirestore.instance.collection('books');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _fetchReadingStats(),
        _fetchReadingHistory(),
        _fetchMonthlyData(),
        _fetchReadingGoals(),
        _fetchGenreData(),
        _fetchBooks(), // Add this line
      ]);
    } catch (e) {
      _showErrorSnackBar('Error fetching data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchReadingStats() async {
    try {
      // Get the stats document
      DocumentSnapshot statsDoc = await _statsCollection.doc('user_stats').get();

      if (statsDoc.exists) {
        setState(() {
          _readingStats = statsDoc.data() as Map<String, dynamic>;
        });
      } else {
        // Create default stats if none exist
        await _createDefaultStats();
      }
    } catch (e) {
      _showErrorSnackBar('Error fetching reading stats: $e');
    }
  }

  Future<void> _fetchBooks() async {
    try {
      QuerySnapshot booksSnapshot = await _booksCollection.get();
      setState(() {
        _books = booksSnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'title': data['title'] ?? 'Unknown Book',
            'author': data['author'] ?? 'Unknown Author',
            'pages': data['pages'] ?? 0,
          };
        }).toList();
      });
    } catch (e) {
      _showErrorSnackBar('Error fetching books: $e');
    }
  }

  Future<void> _createDefaultStats() async {
    final Map<String, dynamic> defaultStats = {
      'totalBooks': 0,
      'booksThisYear': 0,
      'booksThisMonth': 0,
      'totalPages': 0,
      'pagesThisYear': 0,
      'pagesThisMonth': 0,
      'currentStreak': 0,
      'longestStreak': 0,
      'averagePerWeek': 0.0,
      'favorite': {
        'author': 'None',
        'genre': 'None',
      }
    };

    await _statsCollection.doc('user_stats').set(defaultStats);
    _readingStats = defaultStats;
  }

  Future<void> _fetchReadingHistory() async {
    try {
      QuerySnapshot historySnapshot = await _historyCollection
          .orderBy('date', descending: true)
          .limit(20)
          .get();

      setState(() {
        _readingHistory = historySnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'date': data['date'] ?? DateTime.now().toString(),
            'minutes': data['minutes'] ?? 0,
            'pages': data['pages'] ?? 0,
            'book': data['book'] ?? 'Unknown Book',
          };
        }).toList();
      });
    } catch (e) {
      _showErrorSnackBar('Error fetching reading history: $e');
    }
  }

  Future<void> _fetchMonthlyData() async {
    try {
      QuerySnapshot monthlySnapshot = await _monthlyCollection
          .orderBy('monthIndex')
          .get();

      if (monthlySnapshot.docs.isEmpty) {
        await _createDefaultMonthlyData();
      } else {
        setState(() {
          _monthlyData = monthlySnapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'month': data['month'] ?? 'Jan',
              'books': data['books'] ?? 0,
              'pages': data['pages'] ?? 0,
              'monthIndex': data['monthIndex'] ?? 0,
            };
          }).toList();
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error fetching monthly data: $e');
    }
  }

  Future<void> _createDefaultMonthlyData() async {
    List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    List<Map<String, dynamic>> defaultData = [];

    for (int i = 0; i < 12; i++) {
      defaultData.add({
        'month': months[i],
        'books': 0,
        'pages': 0,
        'monthIndex': i,
      });
    }

    // Use a batch to create all documents at once
    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (var data in defaultData) {
      DocumentReference docRef = _monthlyCollection.doc();
      batch.set(docRef, data);
    }

    await batch.commit();
    _monthlyData = defaultData;
  }

  Future<void> _fetchReadingGoals() async {
    try {
      DocumentSnapshot goalsDoc = await _goalCollection.doc('user_goals').get();

      if (goalsDoc.exists) {
        setState(() {
          _readingGoals = goalsDoc.data() as Map<String, dynamic>;
        });
      } else {
        await _createDefaultGoals();
      }
    } catch (e) {
      _showErrorSnackBar('Error fetching reading goals: $e');
    }
  }

  Future<void> _createDefaultGoals() async {
    final Map<String, dynamic> defaultGoals = {
      'yearlyBooks': 20,
      'yearlyBooksProgress': 0,
      'monthlyBooks': 2,
      'monthlyBooksProgress': 0,
      'yearlyPages': 5000,
      'yearlyPagesProgress': 0,
      'weeklyMinutes': 210,
      'weeklyMinutesProgress': 0,
    };

    await _goalCollection.doc('user_goals').set(defaultGoals);
    _readingGoals = defaultGoals;
  }

  Future<void> _fetchGenreData() async {
    try {
      QuerySnapshot genreSnapshot = await _genreCollection.get();

      if (genreSnapshot.docs.isEmpty) {
        await _createDefaultGenreData();
      } else {
        setState(() {
          _genreData = genreSnapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'] ?? 'Unknown',
              'books': data['books'] ?? 0,
              'colorValue': data['colorValue'] ?? Colors.blue.value,
            };
          }).toList();
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error fetching genre data: $e');
    }
  }

  Future<void> _createDefaultGenreData() async {
    List<Map<String, dynamic>> defaultGenres = [
      {'name': 'Fiction', 'books': 0, 'colorValue': Colors.blue.value},
      {'name': 'Non-Fiction', 'books': 0, 'colorValue': Colors.green.value},
      {'name': 'Mystery', 'books': 0, 'colorValue': Colors.purple.value},
      {'name': 'Science', 'books': 0, 'colorValue': Colors.orange.value},
      {'name': 'History', 'books': 0, 'colorValue': Colors.red.value},
    ];

    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (var genre in defaultGenres) {
      DocumentReference docRef = _genreCollection.doc();
      batch.set(docRef, genre);
    }

    await batch.commit();
    _genreData = defaultGenres;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Stats'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'History'),
            Tab(text: 'Goals'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildHistoryTab(),
          _buildGoalsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _fetchAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeframeSelector(),
            const SizedBox(height: 24),
            _buildStatsSummary(),
            const SizedBox(height: 24),
            _buildReadingChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTimeframe,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          items: ['This Week', 'This Month', 'This Year', 'All Time']
              .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedTimeframe = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    // Display different stats based on selected timeframe
    int booksCount, pagesCount;

    switch (_selectedTimeframe) {
      case 'This Week':
        booksCount = _getWeeklyBookCount();
        pagesCount = _getWeeklyPageCount();
        break;
      case 'This Month':
        booksCount = _readingStats['booksThisMonth'] ?? 0;
        pagesCount = _readingStats['pagesThisMonth'] ?? 0;
        break;
      case 'This Year':
        booksCount = _readingStats['booksThisYear'] ?? 0;
        pagesCount = _readingStats['pagesThisYear'] ?? 0;
        break;
      case 'All Time':
      default:
        booksCount = _readingStats['totalBooks'] ?? 0;
        pagesCount = _readingStats['totalPages'] ?? 0;
        break;
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard('Books Read', booksCount.toString(), Icons.menu_book)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard('Pages Read', pagesCount.toString(), Icons.description)),
          ],
        ),
      ],
    );
  }

  int _getWeeklyBookCount() {
    // Count books read in the past week
    DateTime now = DateTime.now();
    DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
    weekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);

    // Get unique book names from reading history
    Set<String> uniqueBooks = {};

    for (var session in _readingHistory) {
      try {
        DateTime sessionDate = DateTime.parse(session['date'] as String);
        if (sessionDate.isAfter(weekStart) || sessionDate.isAtSameMomentAs(weekStart)) {
          uniqueBooks.add(session['book']);
        }
      } catch (e) {
        // Skip invalid dates
      }
    }

    return uniqueBooks.length;
  }

  int _getWeeklyPageCount() {
    // Count pages read in the past week
    DateTime now = DateTime.now();
    DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
    weekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);

    int pages = 0;
    for (var session in _readingHistory) {
      try {
        DateTime sessionDate = DateTime.parse(session['date'] as String);
        if (sessionDate.isAfter(weekStart) || sessionDate.isAtSameMomentAs(weekStart)) {
          pages += session['pages'] as int;
        }
      } catch (e) {
        // Skip invalid dates
      }
    }

    return pages;
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reading Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '2025 Reading Activity',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildBarChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    // Simplified chart implementation
    // In a real app, you would use a charting library like fl_chart
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: _monthlyData.map((data) {
        final double maxBooks = _monthlyData
            .map((m) => m['books'] as int)
            .reduce((value, element) => value > element ? value : element)
            .toDouble();

        final double height = (data['books'] as int) > 0 ?
        (data['books'] as int) / (maxBooks > 0 ? maxBooks : 1) * 150 : 0;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  data['month'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        // Calendar view toggle (simplified)
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('MMMM yyyy').format(DateTime.now()),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.add,
                  color: Theme.of(context).primaryColor,
                ),
                onPressed: () {
                  _showAddReadingSessionDialog();
                },
              ),
            ],
          ),
        ),

        // Reading session history
        Expanded(
          child: _readingHistory.isEmpty
              ? Center(
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
                  'No Reading Sessions Yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track your first reading session',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: _fetchReadingHistory,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _readingHistory.length,
              itemBuilder: (context, index) {
                final session = _readingHistory[index];
                DateTime date;
                try {
                  date = DateTime.parse(session['date'] as String);
                } catch (e) {
                  date = DateTime.now();
                }
                final formattedDate = DateFormat('MMM d, yyyy').format(date);

                return Dismissible(
                  key: Key(session['id']),
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
                          title: const Text('Delete Reading Session'),
                          content: const Text('Are you sure you want to delete this reading session?'),
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
                    _deleteReadingSession(session['id']);
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.auto_stories,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      title: Text(
                        session['book'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(formattedDate),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.timer,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text('${session['minutes']} minutes'),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.description,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text('${session['pages']} pages'),
                            ],
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          _showEditReadingSessionDialog(session);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddReadingSessionDialog() async {
    String? selectedBookId;
    String? selectedBookTitle;
    int? selectedBookPages;
    final minutesController = TextEditingController();
    final pagesController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    // For updating UI when date changes
    StateSetter? dialogState;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          dialogState = setState;
          return AlertDialog(
            title: const Text('Add Reading Session'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () async {
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        dialogState!(() {
                          selectedDate = pickedDate;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('MMM d, yyyy').format(selectedDate)),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Book',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedBookId,
                    items: _books.map((book) {
                      return DropdownMenuItem<String>(
                        value: book['id'],
                        child: Text('${book['title']} (${book['author']})'),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        var selected = _books.firstWhere((book) => book['id'] == newValue);
                        selectedBookId = newValue;
                        selectedBookTitle = selected['title'];
                        selectedBookPages = selected['pages'];
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: minutesController,
                    decoration: const InputDecoration(
                      labelText: 'Minutes Read',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pagesController,
                    decoration: const InputDecoration(
                      labelText: 'Pages Read',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
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
                  if (selectedBookId != null &&
                      minutesController.text.isNotEmpty &&
                      pagesController.text.isNotEmpty) {
                    _addReadingSession(
                      selectedDate.toString(),
                      selectedBookTitle!,
                      int.parse(minutesController.text),
                      int.parse(pagesController.text),
                    );
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in all fields'),
                      ),
                    );
                  }
                },
                child: const Text('ADD'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditReadingSessionDialog(Map<String, dynamic> session) async {
    String? selectedBookId = _books.firstWhere(
          (book) => book['title'] == session['book'],
      orElse: () => {'id': null},
    )['id'];
    String? selectedBookTitle = session['book'];
    int? selectedBookPages;
    final minutesController = TextEditingController(text: (session['minutes'] as int).toString());
    final pagesController = TextEditingController(text: (session['pages'] as int).toString());
    DateTime selectedDate;
    try {
      selectedDate = DateTime.parse(session['date'] as String);
    } catch (e) {
      selectedDate = DateTime.now();
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Reading Session'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    selectedDate = pickedDate;
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMM d, yyyy').format(selectedDate)),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Book',
                  border: OutlineInputBorder(),
                ),
                value: selectedBookId,
                items: _books.map((book) {
                  return DropdownMenuItem<String>(
                    value: book['id'],
                    child: Text('${book['title']} (${book['author']})'),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    var selected = _books.firstWhere((book) => book['id'] == newValue);
                    selectedBookId = newValue;
                    selectedBookTitle = selected['title'];
                    selectedBookPages = selected['pages'];
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: minutesController,
                decoration: const InputDecoration(
                  labelText: 'Minutes Read',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pagesController,
                decoration: const InputDecoration(
                  labelText: 'Pages Read',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
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
              if (selectedBookId != null &&
                  minutesController.text.isNotEmpty &&
                  pagesController.text.isNotEmpty) {
                _updateReadingSession(
                  session['id'],
                  selectedDate.toString(),
                  selectedBookTitle!,
                  int.parse(minutesController.text),
                  int.parse(pagesController.text),
                );
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                  ),
                );
              }
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  Future<void> _addReadingSession(
      String date,
      String book,
      int minutes,
      int pages,
      ) async {
    try {
      DocumentReference docRef = await _historyCollection.add({
        'date': date,
        'book': book,
        'minutes': minutes,
        'pages': pages,
      });

      // Update stats with the session date
      await _updateStats(true, book, pages, sessionDate: date);

      // Update UI
      await _fetchReadingHistory();
    } catch (e) {
      _showErrorSnackBar('Error adding reading session: $e');
    }
  }

  Future<void> _updateReadingSession(
      String id,
      String date,
      String book,
      int minutes,
      int pages,
      ) async {
    try {
      // Get the original session to calculate stats difference
      DocumentSnapshot originalSession = await _historyCollection.doc(id).get();
      Map<String, dynamic> originalData = originalSession.data() as Map<String, dynamic>;
      int originalPages = originalData['pages'] as int;
      String originalDate = originalData['date'] as String;

      // Update the session
      await _historyCollection.doc(id).update({
        'date': date,
        'book': book,
        'minutes': minutes,
        'pages': pages,
      });

      // If the date or pages changed, we need to update stats
      if (date != originalDate || pages != originalPages) {
        // First remove the original entry's stats
        await _updateStats(false, originalData['book'] as String, originalPages, sessionDate: originalDate);

        // Then add the new entry's stats
        await _updateStats(true, book, pages, sessionDate: date);
      }

      // Update UI
      await _fetchReadingHistory();
    } catch (e) {
      _showErrorSnackBar('Error updating reading session: $e');
    }
  }

  Future<void> _deleteReadingSession(String id) async {
    try {
      // Get the session to calculate stats difference
      DocumentSnapshot session = await _historyCollection.doc(id).get();
      Map<String, dynamic> data = session.data() as Map<String, dynamic>;
      int pages = data['pages'] as int;
      String book = data['book'] as String;
      String date = data['date'] as String;

      // Delete the session
      await _historyCollection.doc(id).delete();

      // Update stats with the session date
      await _updateStats(false, book, pages, sessionDate: date);

      // Update UI
      await _fetchReadingHistory();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reading session deleted'),
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Error deleting reading session: $e');
    }
  }

  Future<void> _updateStats(bool isAdding, String book, int pages, {String? sessionDate}) async {
    try {
      // Get current stats
      DocumentSnapshot statsDoc = await _statsCollection.doc('user_stats').get();
      Map<String, dynamic> stats = statsDoc.data() as Map<String, dynamic>;

      // Prepare updates
      int totalPages = stats['totalPages'] ?? 0;
      int pagesThisYear = stats['pagesThisYear'] ?? 0;
      int pagesThisMonth = stats['pagesThisMonth'] ?? 0;

      // Parse the session date or use current date if not provided
      DateTime sessionDateTime;
      if (sessionDate != null) {
        try {
          sessionDateTime = DateTime.parse(sessionDate);
        } catch (e) {
          sessionDateTime = DateTime.now();
        }
      } else {
        sessionDateTime = DateTime.now();
      }

      int sessionYear = sessionDateTime.year;
      int sessionMonth = sessionDateTime.month;

      // Get current date for comparison
      DateTime now = DateTime.now();
      int currentYear = now.year;
      int currentMonth = now.month;

      // Update monthly collection for the correct month
      QuerySnapshot monthlySnapshot = await _monthlyCollection
          .where('monthIndex', isEqualTo: sessionMonth - 1) // Zero-based index
          .limit(1)
          .get();

      if (monthlySnapshot.docs.isNotEmpty) {
        DocumentReference monthlyDocRef = monthlySnapshot.docs[0].reference;
        DocumentSnapshot monthlyDoc = monthlySnapshot.docs[0];
        Map<String, dynamic> monthlyData = monthlyDoc.data() as Map<String, dynamic>;

        int monthlyPages = monthlyData['pages'] ?? 0;
        int monthlyBooks = monthlyData['books'] ?? 0;

        // Check if we need to increment the book count based on the history
        Set<String> booksThisMonth = {};
        QuerySnapshot historyThisMonth = await _historyCollection
            .where('date', isGreaterThanOrEqualTo: DateTime(sessionYear, sessionMonth, 1).toString())
            .where('date', isLessThan: DateTime(sessionYear, sessionMonth + 1, 1).toString())
            .get();

        for (var doc in historyThisMonth.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          booksThisMonth.add(data['book'] as String);
        }

        // If adding, also check if this would be a new book
        if (isAdding) {
          bool isNewBook = !booksThisMonth.contains(book);
          if (isNewBook) {
            booksThisMonth.add(book);
          }

          await monthlyDocRef.update({
            'pages': isAdding ? monthlyPages + pages : monthlyPages - pages,
            'books': booksThisMonth.length,
          });

          // Update genre data if it's a new book
          if (isNewBook) {
            await _updateGenreData(book);
          }
        } else {
          // If deleting, recalculate books after removal
          await monthlyDocRef.update({
            'pages': monthlyPages - pages,
            'books': booksThisMonth.length - (booksThisMonth.contains(book) && booksThisMonth.toList().indexOf(book) == booksThisMonth.toList().lastIndexOf(book) ? 1 : 0),
          });
        }
      }

      // Only update the main stats "this month" and "this year" if the session is in the current month/year
      bool isCurrentMonth = sessionYear == currentYear && sessionMonth == currentMonth;
      bool isCurrentYear = sessionYear == currentYear;

      // Update the main stats document
      Map<String, dynamic> statsUpdates = {
        'totalPages': isAdding ? totalPages + pages : totalPages - pages,
      };

      if (isCurrentYear) {
        statsUpdates['pagesThisYear'] = isAdding ? pagesThisYear + pages : pagesThisYear - pages;
      }

      if (isCurrentMonth) {
        statsUpdates['pagesThisMonth'] = isAdding ? pagesThisMonth + pages : pagesThisMonth - pages;
      }

      statsUpdates['booksThisMonth'] = await _countBooksInCurrentMonth();
      statsUpdates['booksThisYear'] = await _countBooksInCurrentYear();
      statsUpdates['totalBooks'] = await _countTotalBooks();

      await _statsCollection.doc('user_stats').update(statsUpdates);

      // Update reading goals progress
      await _updateReadingGoalsProgress();
    } catch (e) {
      _showErrorSnackBar('Error updating stats: $e');
    }
  }

  Future<void> _updateStatsAfterEdit(int oldPages, int newPages) async {
    try {
      int pageDifference = newPages - oldPages;

      // Get current stats
      DocumentSnapshot statsDoc = await _statsCollection.doc('user_stats').get();
      Map<String, dynamic> stats = statsDoc.data() as Map<String, dynamic>;

      // Prepare updates
      int totalPages = stats['totalPages'] ?? 0;
      int pagesThisYear = stats['pagesThisYear'] ?? 0;
      int pagesThisMonth = stats['pagesThisMonth'] ?? 0;

      // Update the main stats document
      await _statsCollection.doc('user_stats').update({
        'totalPages': totalPages + pageDifference,
        'pagesThisYear': pagesThisYear + pageDifference,
        'pagesThisMonth': pagesThisMonth + pageDifference,
      });

      // Update monthly collection
      DateTime now = DateTime.now();
      int currentMonth = now.month;

      QuerySnapshot monthlySnapshot = await _monthlyCollection
          .where('monthIndex', isEqualTo: currentMonth - 1) // Zero-based index
          .limit(1)
          .get();

      if (monthlySnapshot.docs.isNotEmpty) {
        DocumentReference monthlyDocRef = monthlySnapshot.docs[0].reference;
        DocumentSnapshot monthlyDoc = monthlySnapshot.docs[0];
        Map<String, dynamic> monthlyData = monthlyDoc.data() as Map<String, dynamic>;

        int monthlyPages = monthlyData['pages'] ?? 0;

        await monthlyDocRef.update({
          'pages': monthlyPages + pageDifference,
        });
      }

      // Update reading goals progress
      await _updateReadingGoalsProgress();
    } catch (e) {
      _showErrorSnackBar('Error updating stats after edit: $e');
    }
  }

  Future<int> _countBooksInCurrentMonth() async {
    DateTime now = DateTime.now();
    int currentYear = now.year;
    int currentMonth = now.month;

    Set<String> booksThisMonth = {};

    try {
      QuerySnapshot historyThisMonth = await _historyCollection
          .where('date', isGreaterThanOrEqualTo: DateTime(currentYear, currentMonth, 1).toString())
          .where('date', isLessThan: DateTime(currentYear, currentMonth + 1, 1).toString())
          .get();

      for (var doc in historyThisMonth.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        booksThisMonth.add(data['book'] as String);
      }
    } catch (e) {
      _showErrorSnackBar('Error counting books in current month: $e');
    }

    return booksThisMonth.length;
  }

  Future<int> _countBooksInCurrentYear() async {
    DateTime now = DateTime.now();
    int currentYear = now.year;

    Set<String> booksThisYear = {};

    try {
      QuerySnapshot historyThisYear = await _historyCollection
          .where('date', isGreaterThanOrEqualTo: DateTime(currentYear, 1, 1).toString())
          .where('date', isLessThan: DateTime(currentYear + 1, 1, 1).toString())
          .get();

      for (var doc in historyThisYear.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        booksThisYear.add(data['book'] as String);
      }
    } catch (e) {
      _showErrorSnackBar('Error counting books in current year: $e');
    }

    return booksThisYear.length;
  }

  Future<int> _countTotalBooks() async {
    Set<String> allBooks = {};

    try {
      QuerySnapshot allHistory = await _historyCollection.get();

      for (var doc in allHistory.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        allBooks.add(data['book'] as String);
      }
    } catch (e) {
      _showErrorSnackBar('Error counting total books: $e');
    }

    return allBooks.length;
  }

  Future<void> _updateGenreData(String bookTitle) async {
    // For this example, we'll randomly assign a genre
    // In a real app, you would get this from the book data

    try {
      QuerySnapshot genreSnapshot = await _genreCollection.get();

      if (genreSnapshot.docs.isNotEmpty) {
        // Randomly select a genre (in a real app, you'd match the actual genre)
        int randomIndex = DateTime.now().millisecondsSinceEpoch % genreSnapshot.docs.length;
        DocumentReference genreDocRef = genreSnapshot.docs[randomIndex].reference;

        // Increment the book count for this genre
        await genreDocRef.update({
          'books': FieldValue.increment(1),
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error updating genre data: $e');
    }
  }

  Future<void> _updateReadingGoalsProgress() async {
    try {
      // Get current stats
      DocumentSnapshot statsDoc = await _statsCollection.doc('user_stats').get();
      Map<String, dynamic> stats = statsDoc.data() as Map<String, dynamic>;

      // Get current goals
      DocumentSnapshot goalsDoc = await _goalCollection.doc('user_goals').get();
      Map<String, dynamic> goals = goalsDoc.data() as Map<String, dynamic>;

      // Calculate weekly minutes
      DateTime now = DateTime.now();
      DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
      weekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);

      int weeklyMinutes = 0;
      try {
        QuerySnapshot weeklyHistory = await _historyCollection
            .where('date', isGreaterThanOrEqualTo: weekStart.toString())
            .get();

        for (var doc in weeklyHistory.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          weeklyMinutes += data['minutes'] as int;
        }
      } catch (e) {
        _showErrorSnackBar('Error calculating weekly minutes: $e');
      }

      // Update goals progress
      await _goalCollection.doc('user_goals').update({
        'yearlyBooksProgress': stats['booksThisYear'] ?? 0,
        'monthlyBooksProgress': stats['booksThisMonth'] ?? 0,
        'yearlyPagesProgress': stats['pagesThisYear'] ?? 0,
        'weeklyMinutesProgress': weeklyMinutes,
      });
    } catch (e) {
      _showErrorSnackBar('Error updating reading goals progress: $e');
    }
  }

  // Update the streak data
  Future<void> _updateReadingStreak() async {
    try {
      // Get current stats
      DocumentSnapshot statsDoc = await _statsCollection.doc('user_stats').get();
      Map<String, dynamic> stats = statsDoc.data() as Map<String, dynamic>;

      // Check if there is a reading session for today
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);

      QuerySnapshot todayHistory = await _historyCollection
          .where('date', isGreaterThanOrEqualTo: today.toString())
          .where('date', isLessThan: today.add(const Duration(days: 1)).toString())
          .limit(1)
          .get();

      bool readToday = todayHistory.docs.isNotEmpty;

      // Check if there was a reading session yesterday
      DateTime yesterday = today.subtract(const Duration(days: 1));

      QuerySnapshot yesterdayHistory = await _historyCollection
          .where('date', isGreaterThanOrEqualTo: yesterday.toString())
          .where('date', isLessThan: yesterday.add(const Duration(days: 1)).toString())
          .limit(1)
          .get();

      bool readYesterday = yesterdayHistory.docs.isNotEmpty;

      // Get current streak
      int currentStreak = stats['currentStreak'] ?? 0;
      int longestStreak = stats['longestStreak'] ?? 0;

      // Update streak
      if (readToday) {
        if (readYesterday || currentStreak == 0) {
          // Continue or start streak
          currentStreak = readYesterday ? currentStreak + 1 : 1;
        }
      } else if (!readYesterday) {
        // Reset streak if missed 2 days
        currentStreak = 0;
      }

      // Update longest streak if needed
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }

      // Update stats
      await _statsCollection.doc('user_stats').update({
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
      });
    } catch (e) {
      _showErrorSnackBar('Error updating reading streak: $e');
    }
  }

  Widget _buildGoalsTab() {
    return RefreshIndicator(
      onRefresh: _fetchAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGoalSection(),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _showEditGoalsDialog();
              },
              icon: const Icon(Icons.edit),
              label: const Text('EDIT GOALS'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),
            _buildAchievementsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSection() {
    if (_readingGoals.isEmpty) {
      return const Center(
        child: Text('Loading goals...'),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reading Goals',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Track your progress towards your reading targets',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            _buildGoalItem(
              title: 'Yearly Books Goal',
              current: _readingGoals['yearlyBooksProgress'] ?? 0,
              target: _readingGoals['yearlyBooks'] ?? 20,
              suffix: 'books',
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            _buildGoalItem(
              title: 'Monthly Books Goal',
              current: _readingGoals['monthlyBooksProgress'] ?? 0,
              target: _readingGoals['monthlyBooks'] ?? 2,
              suffix: 'books',
              color: Colors.purple,
            ),
            const SizedBox(height: 16),
            _buildGoalItem(
              title: 'Pages This Year',
              current: _readingGoals['yearlyPagesProgress'] ?? 0,
              target: _readingGoals['yearlyPages'] ?? 5000,
              suffix: 'pages',
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            _buildGoalItem(
              title: 'Weekly Reading Time',
              current: _readingGoals['weeklyMinutesProgress'] ?? 0,
              target: _readingGoals['weeklyMinutes'] ?? 210,
              suffix: 'minutes',
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalItem({
    required String title,
    required int current,
    required int target,
    required String suffix,
    required Color color,
  }) {
    final double progress = target > 0 ? current / target : 0;
    final bool completed = current >= target;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                Text(
                  '$current/$target $suffix',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (completed)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.check_circle,
                      color: color,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress > 1 ? 1 : progress,
          backgroundColor: Colors.grey[200],
          color: color,
          minHeight: 10,
          borderRadius: BorderRadius.circular(5),
        ),
      ],
    );
  }

  Widget _buildAchievementsSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Achievements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Milestones in your reading journey',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAchievementItem(
                  icon: Icons.auto_stories,
                  title: 'First Book',
                  color: Colors.blue,
                  achieved: (_readingStats['totalBooks'] ?? 0) >= 1,
                ),
                _buildAchievementItem(
                  icon: Icons.local_fire_department,
                  title: 'Third Book',
                  color: Colors.blue,
                  achieved: (_readingStats['totalBooks'] ?? 0) >= 3,
                ),
                _buildAchievementItem(
                  icon: Icons.menu_book,
                  title: '5 Books',
                  color: Colors.green,
                  achieved: (_readingStats['totalBooks'] ?? 0) >= 5,
                ),
                _buildAchievementItem(
                  icon: Icons.military_tech,
                  title: '10 Books',
                  color: Colors.blue,
                  achieved: (_readingStats['totalBooks'] ?? 0) >= 10,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementItem({
    required IconData icon,
    required String title,
    required Color color,
    required bool achieved,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: achieved ? color : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: achieved ? Colors.white : Colors.grey[500],
            size: 30,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: achieved ? Colors.black87 : Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showEditGoalsDialog() {
    final yearlyBooksController = TextEditingController(
      text: (_readingGoals['yearlyBooks'] ?? 20).toString(),
    );
    final monthlyBooksController = TextEditingController(
      text: (_readingGoals['monthlyBooks'] ?? 2).toString(),
    );
    final yearlyPagesController = TextEditingController(
      text: (_readingGoals['yearlyPages'] ?? 5000).toString(),
    );
    final weeklyMinutesController = TextEditingController(
      text: (_readingGoals['weeklyMinutes'] ?? 210).toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Reading Goals'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: yearlyBooksController,
                decoration: const InputDecoration(
                  labelText: 'Books per Year',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: monthlyBooksController,
                decoration: const InputDecoration(
                  labelText: 'Books per Month',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: yearlyPagesController,
                decoration: const InputDecoration(
                  labelText: 'Pages per Year',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: weeklyMinutesController,
                decoration: const InputDecoration(
                  labelText: 'Minutes per Week',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
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
            onPressed: () async {
              try {
                // Update goals
                await _goalCollection.doc('user_goals').update({
                  'yearlyBooks': int.parse(yearlyBooksController.text),
                  'monthlyBooks': int.parse(monthlyBooksController.text),
                  'yearlyPages': int.parse(yearlyPagesController.text),
                  'weeklyMinutes': int.parse(weeklyMinutesController.text),
                });

                // Refresh goals
                await _fetchReadingGoals();

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reading goals updated successfully'),
                  ),
                );
              } catch (e) {
                _showErrorSnackBar('Error updating goals: $e');
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}