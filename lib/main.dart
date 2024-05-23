import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const WordleNextApp());
}

class WordleNextApp extends StatelessWidget {
  const WordleNextApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wordle Helper',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const WordleNext(),
    );
  }
}

class WordleNext extends StatefulWidget {
  const WordleNext({super.key});

  @override
  _WordleNextState createState() => _WordleNextState();
}

class _WordleNextState extends State<WordleNext> {
  final List<List<String>> _guesses = List.generate(6, (index) => List.filled(5, ''));
  final List<List<String>> _feedback = List.generate(6, (index) => List.filled(5, 'white'));
  List<String> _suggestions = [];
  List<String> _validWords = [];
  final List<List<FocusNode>> _focusNodes = List.generate(6, (index) => List.generate(5, (index) => FocusNode()));
  final List<List<TextEditingController>> _controllers = List.generate(6, (index) => List.generate(5, (index) => TextEditingController()));

  @override
  void initState() {
    super.initState();
    _loadValidWords();
  }

  /// Loads the list of valid words from a file and updates the state with the loaded words.
  Future<void> _loadValidWords() async {
    // Load the file containing the list of valid words from the root bundle
    try {
      String wordsString = await rootBundle.loadString('data/valid-wordle-words.txt');
      List<String> words = wordsString.split('\n').map((word) => word.trim().toUpperCase()).toList();
      setState(() {
        _validWords = words;
        _generateSuggestions();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading valid words: $e');
      }
    }
  }

  void _generateSuggestions() {
    List<String> suggestions = _generateWordSuggestions();
    setState(() {
      _suggestions = suggestions;
    });
  }

  List<String> _generateWordSuggestions() {
    List<String> suggestions = [];
    // Filter valid words by length and feedback
    List<String> filteredWords = [];
    for (String word in _validWords) {
      if (word.length == 5 && _matchesFeedback(word)) {
        filteredWords.add(word.toUpperCase());
      }
    }

    // Calculate letter frequency
    Map<String, int> letterFrequency = _calculateLetterFrequency(filteredWords);

    // Calculate scores for each word
    Map<String, int> wordScores = {};
    for (var word in filteredWords) {
      wordScores[word] = _calculateWordScore(word, letterFrequency);
    }

    // Sort words by score in descending order and limit to 5 suggestions
    suggestions = wordScores.keys.toList()
      ..sort((a, b) => wordScores[b]!.compareTo(wordScores[a]!));
    return suggestions.take(5).toList();
  }

  Map<String, int> _calculateLetterFrequency(List<String> words) {
    Map<String, int> frequency = {};
    for (var word in words) {
      for (var letter in word.split('')) {
        if (frequency.containsKey(letter)) {
          frequency[letter] = frequency[letter]! + 1;
        } else {
          frequency[letter] = 1;
        }
      }
    }
    return frequency;
  }

  int _calculateWordScore(String word, Map<String, int> frequency) {
    int score = 0;
    for (var letter in word.split('')) {
      if (frequency.containsKey(letter)) {
        score += frequency[letter]!;
      }
    }
    return score;
  }

  bool _matchesFeedback(String word) {
    for (int i = 0; i < 6; i++) {
      for (int j = 0; j < 5; j++) {
        if (_feedback[i][j] == 'white') continue;
        if (_feedback[i][j] == 'green' && word[j] != _guesses[i][j]) return false;
        if (_feedback[i][j] == 'yellow' && (word[j] == _guesses[i][j] || !word.contains(_guesses[i][j]))) return false;
        if (_feedback[i][j] == 'gray' && word.contains(_guesses[i][j])) return false;
      }
    }
    return true;
  }

  void _cycleFeedbackColor(int guessIndex, int letterIndex) {
    setState(() {
      String currentColor = _feedback[guessIndex][letterIndex];
      switch (currentColor) {
        case 'white':
          _feedback[guessIndex][letterIndex] = 'gray';
          break;
        case 'gray':
          _feedback[guessIndex][letterIndex] = 'yellow';
          break;
        case 'yellow':
          _feedback[guessIndex][letterIndex] = 'green';
          break;
        case 'green':
          _guesses[guessIndex][letterIndex] = ''; // Clear the letter when cycling back to white
          _feedback[guessIndex][letterIndex] = 'white';
          break;
      }
      _generateSuggestions(); // Update suggestions after feedback has been updated
    });
  }

  bool _isRowEnabled(int rowIndex) {
    if (rowIndex == 0) return true;
    for (var letter in _guesses[rowIndex - 1]) {
      if (letter.isEmpty) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set background to white
      appBar: AppBar(
        title: const Text('Wordle Next'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enter your guesses and click on the letters to change the feedback color:'),
            const SizedBox(height: 20),
            _buildWordleGrid(),
            const SizedBox(height: 20),
            if (_suggestions.isNotEmpty) ...[
              const Text('Suggestions:', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 10),
              for (var suggestion in _suggestions) Text(suggestion),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWordleGrid() {
    return Column(
      children: [
        for (int i = 0; i < 6; i++) _buildGuessRow(i),
      ],
    );
  }

  Widget _buildGuessRow(int guessIndex) {
    bool rowEnabled = _isRowEnabled(guessIndex);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int letterIndex = 0; letterIndex < 5; letterIndex++)
          _buildLetterInput(guessIndex, letterIndex, rowEnabled),
      ],
    );
  }

  /// Builds a letter input widget for the Wordle game.
  ///
  /// The [guessIndex] parameter represents the index of the current guess.
  /// The [letterIndex] parameter represents the index of the letter in the guess.
  /// The [rowEnabled] parameter indicates whether the row is enabled or disabled.
  ///
  /// Returns a widget representing the letter input.
  Widget _buildLetterInput(int guessIndex, int letterIndex, bool rowEnabled) {
    return GestureDetector(
      onTap: _guesses[guessIndex][letterIndex].isNotEmpty
          ? () {
              FocusScope.of(context).unfocus(); // Unfocus to avoid TextField blocking
              _cycleFeedbackColor(guessIndex, letterIndex);
            }
          : null,
      child: Container(
        margin: const EdgeInsets.all(4.0),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
          color: _getColorForFeedback(_feedback[guessIndex][letterIndex]),
        ),
        child: Center(
          child: TextField(
            controller: _controllers[guessIndex][letterIndex],
            focusNode: _focusNodes[guessIndex][letterIndex],
            enabled: rowEnabled && _guesses[guessIndex][letterIndex].isEmpty, // Disable input if a letter is already entered
            onChanged: (value) {
              if (value.length == 1) {
                setState(() {
                  _guesses[guessIndex][letterIndex] = value.toUpperCase(); // Capitalize the letter
                  _feedback[guessIndex][letterIndex] = 'white'; // Reset color to white
                  _controllers[guessIndex][letterIndex].text = value.toUpperCase(); // Ensure uppercase in TextField

                  // Move to next cell
                  if (letterIndex < 4) {
                    _focusNodes[guessIndex][letterIndex + 1].requestFocus();
                  } else if (guessIndex < 5) {
                    _focusNodes[guessIndex + 1][0].requestFocus();
                  }
                });
              }
            },
            maxLength: 1,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              isDense: true, // Reduce padding inside the TextField
              contentPadding: EdgeInsets.all(10), // Adjust padding
            ),
            style: TextStyle(fontSize: 24, color: rowEnabled ? Colors.black : Colors.grey), // Change text color based on enabled state
          ),
        ),
      ),
    );
  }

  Color _getColorForFeedback(String feedback) {
    switch (feedback) {
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.yellow;
      case 'gray':
        return Colors.grey;
      default:
        return Colors.white;
    }
  }
}
