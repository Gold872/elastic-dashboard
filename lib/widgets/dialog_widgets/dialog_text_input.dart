import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DialogTextInput extends StatelessWidget {
  final Function(String value) onSubmit;
  final TextInputFormatter? formatter;
  final String? label;
  final String? initialText;
  final bool allowEmptySubmission;
  final bool enabled;

  TextEditingController? textEditingController;

  bool focused = false;

  DialogTextInput(
      {super.key,
      required this.onSubmit,
      this.label,
      this.initialText,
      this.allowEmptySubmission = false,
      this.enabled = true,
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
          focused = value;
        },
        child: TextField(
          enabled: enabled,
          onSubmitted: (value) {
            if (value.isNotEmpty || allowEmptySubmission) {
              onSubmit.call(value);
            }
          },
          onTapOutside: (_) {
            if (!focused) {
              return;
            }

            String textValue = textEditingController!.text;
            if (textValue.isNotEmpty || allowEmptySubmission) {
              onSubmit.call(textValue);
            }

            FocusManager.instance.primaryFocus?.unfocus();
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
