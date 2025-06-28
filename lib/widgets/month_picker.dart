import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthPickerWidget extends StatelessWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onChanged;

  const MonthPickerWidget({
    Key? key,
    required this.selectedMonth,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () async {
            final picked = await showDialog<DateTime>(
              context: context,
              builder: (context) {
                int year = selectedMonth.year;
                return StatefulBuilder(
                  builder: (context, setState) {
                    return AlertDialog(
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.all(8),
                      title: Padding(
                        padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () {
                                setState(() {
                                  year--;
                                });
                              },
                            ),
                            GestureDetector(
                              onTap: () async {
                                final pickedYear = await showDialog<int>(
                                  context: context,
                                  builder: (context) {
                                    int tempYear = year;
                                    final scrollController = ScrollController(
                                      initialScrollOffset: ((year - (DateTime.now().year - 20)) * 48.0).clamp(0, double.infinity),
                                    );
                                    return AlertDialog(
                                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                                      title: const Text('Choisir une année', style: TextStyle(fontWeight: FontWeight.bold)),
                                      content: SizedBox(
                                        width: 200,
                                        height: 300,
                                        child: ListView.builder(
                                          controller: scrollController,
                                          itemCount: 40,
                                          itemBuilder: (context, i) {
                                            final y = DateTime.now().year - 20 + i;
                                            return ListTile(
                                              title: Text('$y', style: TextStyle(fontWeight: y == year ? FontWeight.bold : FontWeight.normal)),
                                              onTap: () => Navigator.of(context).pop(y),
                                              selected: y == year,
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                );
                                if (pickedYear != null) {
                                  setState(() {
                                    year = pickedYear;
                                  });
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                child: Text('$year', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () {
                                setState(() {
                                  year++;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      content: Padding(
                        padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                        child: SizedBox(
                          width: 320,
                          height: 260,
                          child: GridView.count(
                            crossAxisCount: 3,
                            childAspectRatio: 2.2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            physics: const NeverScrollableScrollPhysics(),
                            children: List.generate(12, (i) {
                              final month = DateTime(year, i + 1);
                              final isSelected = (month.year == selectedMonth.year && month.month == selectedMonth.month);
                              return GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pop(month);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white24),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    DateFormat.MMM('fr_CA').format(month),
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
            if (picked != null) {
              onChanged(picked);
            }
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 15, right: 8, top: 8, bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  DateFormat.yMMMM('fr_CA').format(selectedMonth),
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 20),
                Icon(Icons.arrow_drop_down, size: 28, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
