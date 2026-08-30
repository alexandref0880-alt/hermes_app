import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const HermesApp());

class HermesApp extends StatelessWidget {
  const HermesApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Гермес PRO',
      debugShowCheckedModeBanner: false,
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  final List<String> _projects = ["Общие задачи", "Балашиха", "Дубна", "Кабицино", "Авито контроль"];
  String _currentProject = "Общие задачи";
  final String _deepInfraKey = "9j7aErhX3dyovsbPkkTQYpWTf9fio7qV";

  void _pickFileOrPhoto() {
    setState(() {
      _messages.add({"role": "user", "text": "📸 [Прикреплено изображение объекта]"});
      _messages.add({"role": "hermes", "text": "Вижу изображение. Анализирую состояние объекта для проекта $_currentProject..."});
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Файл прикреплен из галереи')));
  }

  void _startNativeVoiceInput() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Микрофон включен. Слушаю интонацию...')));
    Future.delayed(const Duration(seconds: 2), () {
      setState(() { _controller.text = "Гермес, выведи статус по Балашихе, пожалуйста."; });
    });
  }

  void _speakText(String text) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Озвучиваю ответ Гермеса голосом...')));
  }

  void _showMessageMenu(String text) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF212121),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.volume_up, color: Colors.white),
            title: const Text("Озвучить сообщение голосом"),
            onTap: () {
              Navigator.pop(context);
              _speakText(text);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy, color: Colors.white),
            title: const Text("Копировать текст отчета"),
            onTap: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Текст скопирован')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.share, color: Colors.white),
            title: const Text("Переслать в Пачку / Telegram"),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Окно пересылки открыто')));
            },
          ),
        ],
      ),
    );
  }

  void _showAddProjectDialog() {
    final tc = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF212121),
        title: const Text("Новый проект"),
        content: TextField(controller: tc, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          TextButton(
            onPressed: () {
              if (tc.text.trim().isNotEmpty) {
                setState(() {
                  _projects.add(tc.text.trim());
                  _currentProject = tc.text.trim();
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Создать"),
          ),
        ],
      ),
    );
  }

  void _showRenameProjectDialog(String oldName) {
    final tc = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF212121),
        title: const Text("Переименовать проект"),
        content: TextField(controller: tc, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          TextButton(
            onPressed: () {
              if (tc.text.trim().isNotEmpty && tc.text.trim() != oldName) {
                setState(() {
                  int idx = _projects.indexOf(oldName);
                  if (idx != -1) {
                    _projects[idx] = tc.text.trim();
                    if (_currentProject == oldName) _currentProject = tc.text.trim();
                  }
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Сохранить"),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    final userText = _controller.text;
    setState(() {
      _messages.add({"role": "user", "text": userText});
      _isLoading = true;
    });
    _controller.clear();

    try {
      final response = await http.post(
        Uri.parse("https://deepinfra.com"),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $_deepInfraKey"},
        body: jsonEncode({
          "model": "deepseek-ai/DeepSeek-R1",
          "messages": [
            {"role": "system", "content": "Ты Гермес. Контекст: $_currentProject."},
            {"role": "user", "content": userText}
          ],
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _messages.add({"role": "hermes", "text": data['choices']['message']['content']});
        });
      }
    } catch (e) {
      setState(() { _messages.add({"role": "hermes", "text": "Ошибка сети."}); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF171717),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        title: Text('Гермес • $_currentProject', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0D0D0D),
        child: Column(
          children: [
            const DrawerHeader(child: Center(child: Text('ГЕРМЕС PRO', style: TextStyle(color: Colors.white, fontSize: 20)))),
            ListTile(
              leading: const Icon(Icons.add, color: Colors.white),
              title: const Text("Создать проект", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showAddProjectDialog();
              },
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _projects.length,
                itemBuilder: (context, index) {
                  final name = _projects[index];
                  final sel = name == _currentProject;
                  return ListTile(
                    tileColor: sel ? const Color(0xFF212121) : null,
                    title: Text(name, style: TextStyle(color: sel ? Colors.white : Colors.grey)),
                    trailing: name != "Общие задачи" ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.grey, size: 18),
                          onPressed: () => _showRenameProjectDialog(name),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                          onPressed: () {
                            setState(() {
                              _projects.remove(name);
                              if (_currentProject == name) _currentProject = "Общие задачи";
                            });
                          },
                        ),
                      ],
                    ) : null,
                    onTap: () {
                      setState(() { _currentProject = name; });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["role"] == "user";
                final txt = msg["text"] ?? "";
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: GestureDetector(
                    onLongPress: () => _showMessageMenu(txt),
                    onTap: () => _showMessageMenu(txt),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? const Color(0xFF212121) : const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(txt, style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                );
