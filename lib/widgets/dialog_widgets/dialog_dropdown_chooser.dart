import 'package:flutter/material.dart';

class DialogDropdownChooser<T> extends StatefulWidget {
  final List<T>? choices;
  final T? initialValue;
  final Function(T?) onSelectionChanged;

  const DialogDropdownChooser(
      {super.key,
      this.choices,
      this.initialValue,
      required this.onSelectionChanged});

  @override
  State<DialogDropdownChooser<T>> createState() =>
      _DialogDropdownChooserState<T>();
}

class _DialogDropdownChooserState<T> extends State<DialogDropdownChooser<T>> {
  late T? selectedValue;

  @override
  void initState() {
    super.initState();

    selectedValue = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: ExcludeFocus(
            child: DropdownButton(
              isExpanded: true,
              borderRadius: BorderRadius.circular(8.0),
              style: const TextStyle(fontWeight: FontWeight.normal),
              items: widget.choices?.map((T item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(item.toString()),
                );
              }).toList(),
              value: selectedValue,
              onChanged: (value) {
                setState(() {
                  selectedValue = value;

                  widget.onSelectionChanged.call(value);
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
