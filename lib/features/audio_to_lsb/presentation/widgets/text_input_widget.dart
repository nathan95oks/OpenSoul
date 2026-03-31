import 'package:flutter/material.dart';

class TextInputWidget extends StatefulWidget {
  final Function(String) onSubmit;

  const TextInputWidget({Key? key, required this.onSubmit}) : super(key: key);

  @override
  State<TextInputWidget> createState() => _TextInputWidgetState();
}

class _TextInputWidgetState extends State<TextInputWidget> {
  final TextEditingController _controller = TextEditingController();

  void _submit() {
    if (_controller.text.trim().isNotEmpty) {
      widget.onSubmit(_controller.text.trim());
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F).withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Escribe o usa el micrófono...",
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Color(0xFFFFD700)),
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
