import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DialogTextInput extends StatelessWidget {
  final Function(String value) onSubmit;
  final TextInputFormatter? formatter;
  final String? label;
  final String? initialText;
  final bool allowEmptySubmission;

  TextEditingController? textEditingController;

  DialogTextInput(
      {super.key,
      required this.onSubmit,
      this.label,
      this.initialText,
      this.allowEmptySubmission = false,
      this.formatter,
      this.textEditingController}) {
    textEditingController ??= TextEditingController(text: initialText);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Focus(
        onFocusChange: (value) {
          // Don't consider the text submitted when focus is gained
          if (value) {
            return;
          }
          String textValue = textEditingController!.text;
          if (textValue.isNotEmpty || allowEmptySubmission) {
            onSubmit.call(textValue);
          }
        },
        child: TextField(
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              onSubmit.call(value);
            }
          },
          controller: textEditingController,
          inputFormatters: (formatter != null) ? [formatter!] : null,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
    );
  }
}
