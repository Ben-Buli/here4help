import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SixDigitCodeField extends StatefulWidget {
  final TextEditingController controller;
  final String? helperText;
  final String? Function(String?)? validator;
  final bool useBoxes; // true: 方格, false: 底線

  const SixDigitCodeField({
    super.key,
    required this.controller,
    this.helperText,
    this.validator,
    this.useBoxes = true,
  });

  @override
  State<SixDigitCodeField> createState() => _SixDigitCodeFieldState();
}

class _SixDigitCodeFieldState extends State<SixDigitCodeField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (_) => TextEditingController());
    _nodes = List.generate(6, (_) => FocusNode());

    final init = widget.controller.text.trim();
    for (int i = 0; i < 6; i++) {
      _controllers[i].text = i < init.length ? init[i] : '';
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _syncOuter() {
    widget.controller.text = _controllers.map((c) => c.text).join();
  }

  @override
  Widget build(BuildContext context) {
    final fields = List.generate(6, (index) {
      return SizedBox(
        width: 44,
        child: TextField(
          controller: _controllers[index],
          focusNode: _nodes[index],
          textAlign: TextAlign.center,
          maxLength: 1,
          keyboardType: TextInputType.number,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: widget.useBoxes
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  )
                : const UnderlineInputBorder(),
            focusedBorder: widget.useBoxes
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary, width: 2),
                  )
                : UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
          ),
          onChanged: (value) {
            if (value.isNotEmpty) {
              _controllers[index].text = value[value.length - 1];
              _controllers[index].selection = TextSelection.fromPosition(
                  TextPosition(offset: _controllers[index].text.length));
              if (index < 5) {
                _nodes[index + 1].requestFocus();
              } else {
                _nodes[index].unfocus();
              }
            } else {
              if (index > 0) {
                _nodes[index - 1].requestFocus();
              }
            }
            _syncOuter();
            setState(() {});
          },
          onSubmitted: (_) {
            if (index < 5) _nodes[index + 1].requestFocus();
          },
        ),
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: fields,
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.helperText!,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
        if (widget.validator != null)
          Builder(builder: (context) {
            final err = widget.validator!(widget.controller.text);
            if (err == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(err,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12)),
            );
          })
      ],
    );
  }
}
