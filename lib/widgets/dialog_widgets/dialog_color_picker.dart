import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class DialogColorPicker extends StatefulWidget {
  final Function(Color color) onColorPicked;
  final String label;
  final Color initialColor;
  final double padding;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  const DialogColorPicker({
    super.key,
    required this.onColorPicked,
    required this.label,
    required this.initialColor,
    this.padding = 32,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  State<DialogColorPicker> createState() => _DialogColorPickerState();
}

class _DialogColorPickerState extends State<DialogColorPicker> {
  late Color initialColor;
  Color? selectedColor;

  TextEditingController hexInputController = TextEditingController();

  @override
  void initState() {
    super.initState();

    initialColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: widget.mainAxisAlignment,
      crossAxisAlignment: widget.crossAxisAlignment,
      children: [
        Text(widget.label),
        const SizedBox(width: 8), // Adjust the width as needed
        ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Select Color'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: selectedColor ?? initialColor,
                          enableAlpha: false,
                          hexInputBar: true,
                          hexInputController: hexInputController,
                          onColorChanged: (Color color) {
                            setState(() {
                              selectedColor = color;
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: hexInputController,
                          autofocus: false,
                          decoration: InputDecoration(
                            constraints: const BoxConstraints(
                              maxWidth: 150,
                            ),
                            contentPadding:
                                const EdgeInsets.fromLTRB(8, 4, 8, 4),
                            labelText: 'Hex Code',
                            prefixText: '#',
                            counterText: '',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4)),
                          ),
                          maxLength: 6,
                          inputFormatters: [
                            UpperCaseTextFormatter(),
                            FilteringTextInputFormatter.allow(
                                RegExp(kValidHexPattern)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                        widget.onColorPicked.call(initialColor);

                        setState(() {
                          selectedColor = initialColor;
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                        widget.onColorPicked
                            .call(selectedColor ?? initialColor);

                        setState(() {
                          initialColor = selectedColor ?? initialColor;
                        });
                      },
                      child: const Text('Save'),
                    ),
                  ],
                );
              },
            ).then((value) {
              bool dismissed = value ?? true;
              if (dismissed) {
                widget.onColorPicked.call(initialColor);

                setState(() {
                  selectedColor = initialColor;
                });
              }
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: selectedColor ?? initialColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7.5),
            ),
          ),
          child: SizedBox(
            width: widget.padding,
            height: widget.padding,
          ),
        ),
      ],
    );
  }
}
