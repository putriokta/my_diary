// ignore_for_file: use_build_context_synchronously, avoid_function_literals_in_foreach_calls

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MaterialApp(
    home: HomePage(),
  ));
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;
  List<Note> notes = [];
  StreamSubscription<QuerySnapshot>? _notesSubscription;

  @override
  void initState() {
    super.initState();
    _setUpNotesListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setUpNotesListener();
  }

  void _setUpNotesListener() {
    final notesCollection = FirebaseFirestore.instance.collection('notes');
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      _notesSubscription?.cancel();
      _notesSubscription = notesCollection
          .doc(userId)
          .collection("note_user")
          .snapshots()
          .listen((snapshot) {
        List<Note> newNotes = [];
        for (var doc in snapshot.docs) {
          newNotes.add(Note(
            title: doc['title'],
            content: doc['content'],
            time: doc['time'],
            id: doc.id,
          ));
        }
        setState(() {
          notes = newNotes;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("My Diary"),
        backgroundColor: const Color.fromARGB(255, 161, 124, 224),
        actions: [
          IconButton(
            onPressed: () {
              if (user != null) {
                FirebaseAuth.instance.signOut();
              } else {
                Navigator.pushNamed(context, '/login');
              }
            },
            icon: user != null
                ? const Icon(Icons.logout)
                : const Icon(Icons.login),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Halo, Selamat Datang :)",
              style: GoogleFonts.roboto(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8.0), // Tambahkan spasi vertikal di sini
            Text(
              "Catatan Terbaru",
              style: GoogleFonts.roboto(
                color: Colors.black,
                fontSize: 16, // Ganti ukuran font untuk "Catatan Terbaru"
              ),
            ),
            const SizedBox(
              height: 20.0,
            ),
            Expanded(
              child: ListView(
                children: notes.map((note) {
                  return NoteCard(
                    note: note,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => FullNotePage(note: note),
                        ),
                      );
                    },
                    onDelete: () async {
                       final userId = FirebaseAuth.instance.currentUser?.uid;
                      if (userId != null && note.id != null) {
                        await FirebaseFirestore.instance
                          .collection('notes')
                          .doc(userId)
                          .collection("note_user")
                          .doc(note.id)
                          .delete();

                        setState(() {
                          notes.remove(note);
                        });
                      }
                    },
                    onEdit: () {
                      _editNoteDialog(note);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _addNoteDialog();
        },
        backgroundColor: const Color.fromARGB(255, 161, 124, 224),
        child: const Icon(Icons.add),
      ),
    );
  }

//form tambah catatan
  Future<void> _addNoteDialog() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController contentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Tambah Catatan Baru"),
          content: SizedBox(
            width: 300,
            height : 150,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: "Judul",
                    ),
                  ),
                  TextField(
                    controller: contentController,
                    maxLines: null,
                    decoration: const InputDecoration(
                      labelText: "Isi Catatan",
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final title = titleController.text;
                final content = contentController.text;
                final time = DateTime.now().toString();

                if (title.isNotEmpty && content.isNotEmpty) {
                  final notesCollection =
                      FirebaseFirestore.instance.collection('notes');
                  final userId = FirebaseAuth.instance.currentUser?.uid;
                  if (userId != null) {
                    final newNoteRef = await notesCollection
                        .doc(userId)
                        .collection("note_user")
                        .add({
                          'title': title,
                          'content': content,
                          'time': time,
                        });

                    final newNoteId = newNoteRef.id;

                    setState(() {
                      notes.add(
                        Note(
                          title: title,
                          content: content,
                          time: time,
                          id: newNoteId,
                        ),
                      );
                    });
                    titleController.clear();
                    contentController.clear();
                    Navigator.of(context).pop();

                    _setUpNotesListener(); // Panggil kembali _listener_
                  }
                }
              },
              child: const Text("Simpan"),
            ),
            TextButton(
              onPressed: () {
                titleController.clear();
                contentController.clear();
                Navigator.of(context).pop();
              },
              child: const Text("Batal"),
            ),
          ],
        );
      },
    );
  }

Future<void> _editNoteDialog(Note note) async {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  titleController.text = note.title;
  contentController.text = note.content;

  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Edit Catatan"),
        content: SizedBox(
            width: 300,
            height : 150,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: "Judul",
                    ),
                  ),
                  TextField(
                    controller: contentController,
                    maxLines: null,
                    decoration: const InputDecoration(
                      labelText: "Isi Catatan",
                    ),
                  ),
                ],
              ),
            ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final newTitle = titleController.text;
              final newContent = contentController.text;
              final newTime = DateTime.now().toString();

              if (newTitle.isNotEmpty && newContent.isNotEmpty) {
                final userId = FirebaseAuth.instance.currentUser?.uid;

                if (userId != null) {
                  // Perbarui catatan di Firestore berdasarkan ID catatan
                  await FirebaseFirestore.instance
                      .collection('notes')
                      .doc(userId)
                      .collection("note_user")
                      .doc(note.id!) // Gunakan note.id di sini
                      .update({
                        'title': newTitle,
                        'content': newContent,
                        'time': newTime,
                      });

                  setState(() {
                    note.title = newTitle;
                    note.content = newContent;
                    note.time = newTime;
                  });

                  titleController.clear();
                  contentController.clear();
                  Navigator.of(context).pop();
                }
              }
            },
            child: const Text("Simpan"),
          ),
          TextButton(
            onPressed: () {
              titleController.clear();
              contentController.clear();
              Navigator.of(context).pop();
            },
            child: const Text("Batal"),
          ),
        ],
      );
    },
  );
}

}

class Note {
  String title;
  String content;
  String time;
  String? id;

  Note({
    required this.title,
    required this.content,
    required this.time,
    required this.id,
  });

  // String? get id => null;
}

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(10),
      child: ListTile(
        title: Text(note.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.content,
              maxLines: 2, // Menampilkan maksimal 2 baris pada tampilan awal
              overflow: TextOverflow
                  .ellipsis, // Menampilkan elipsis (...) jika lebih dari 2 baris
            ),
            const SizedBox(height: 4),
            Text(
              "Waktu: ${note.time}",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class FullNotePage extends StatefulWidget {
  final Note note;

  const FullNotePage({super.key, required this.note});

  @override
  // ignore: library_private_types_in_public_api
  _FullNotePageState createState() => _FullNotePageState();
}

class _FullNotePageState extends State<FullNotePage> {
  bool _isEditing = false;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.note.content);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note.title),
        actions: [
          IconButton(
            icon: _isEditing ? const Icon(Icons.check) : const Icon(Icons.edit),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
              if (!_isEditing) {
                // Simpan perubahan jika tidak sedang mengedit
                final newContent = _contentController.text;
                final newTime = DateTime.now().toString();

                if (newContent.isNotEmpty) {
                  setState(() {
                    widget.note.content = newContent;
                    widget.note.time = newTime;
                  });
                }
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Isi Catatan:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(
              height: 10.0,
            ),
            _isEditing
                ? TextField(
                    controller: _contentController,
                    maxLines: null, // Tidak ada batasan pada jumlah baris
                    decoration: const InputDecoration(
                      labelText: "Isi Catatan",
                    ),
                  )
                : Text(
                    widget.note.content,
                    style: const TextStyle(fontSize: 16),
                  ),
            const SizedBox(
              height: 20.0,
            ),
            Text(
              "Waktu: ${widget.note.time}",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}
