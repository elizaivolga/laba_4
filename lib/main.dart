import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart'; // Для форматирования времени

void main() async {
  runApp(const MyApp());
  var result = await Connectivity().checkConnectivity();
  if(result[0] == ConnectivityResult.none){
    Fluttertoast.showToast(
        msg: "Отсутствует подключение к интернету",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Лабораторная работа №4'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Database _database;
  List<Map<String, dynamic>> _songs = [];

  @override
  void initState() {
    super.initState();
    _initDatabase();
    Timer.periodic(const Duration(seconds: 20), (timer) async {
      await fetchCurrentSong();
    });
  }

  // Инициализация базы данных
  Future<void> _initDatabase() async {
    _database = await openDatabase(
      join(await getDatabasesPath(), 'songs.db'),
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE songs(id INTEGER PRIMARY KEY AUTOINCREMENT, artist TEXT, title TEXT, time TEXT)",
        );
      },
      version: 1,
    );
    _loadSongs();
  }

  // Загрузка песен из базы данных
  Future<void> _loadSongs() async {
    final List<Map<String, dynamic>> songs = await _database.query('songs');
    setState(() {
      _songs = songs;
    });
  }

  // Добавление песни в базу данных
  Future<void> _addSong(String artist, String title) async {
    final now = DateTime.now();
    final time = DateFormat('dd.MM.yy HH:mm:ss').format(now);  // Форматирование времени

    final existingSong = await _database.query(
      'songs',
      where: 'title = ?',
      whereArgs: [title],
    );

    if (existingSong.isEmpty) {
      await _database.insert(
        'songs',
        {'artist': artist, 'title': title, 'time': time},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _loadSongs();  // Обновляем список песен
    }
  }

  // Асинхронный запрос для получения данных о текущей песне
  Future<void> fetchCurrentSong() async {
    final url = Uri.parse('https://webradio.io/api/radio/ezia/current-song');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final artist = data['artist'];
        final title = data['title'];
        await _addSong(artist, title);  // Добавляем песню в базу данных
      } else {
        print('Ошибка: не удалось получить данные');
      }
    } catch (e) {
      print('Ошибка запроса: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.all(10),
            child: Table(
              border: TableBorder.all(),
              children: [
                TableRow(
                  children: [
                    Text(
                      'ID',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Исполнитель',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Название трека',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Время внесения записи',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                // Динамическое отображение данных из базы данных
                for (var song in _songs)
                  TableRow(
                    children: [
                      Text(song['id'].toString(), textAlign: TextAlign.center),
                      Text(song['artist'], textAlign: TextAlign.center),
                      Text(song['title'], textAlign: TextAlign.center),
                      Text(song['time'], textAlign: TextAlign.center),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
