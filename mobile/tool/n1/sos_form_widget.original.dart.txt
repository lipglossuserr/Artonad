
import 'package:flutter/material.dart';

class SosFormWidget extends StatefulWidget {
  final String initialEmergencyType;
  final int initialPeopleCount;

  final void Function(
    String emergencyType,
    int peopleCount,
    String note,
  ) onSubmit;

  const SosFormWidget({
    super.key,
    required this.onSubmit,
    this.initialEmergencyType = 'FIRE',
    this.initialPeopleCount = 1,
  });

  @override
  State<SosFormWidget> createState() => _SosFormWidgetState();
}

class _SosFormWidgetState extends State<SosFormWidget> {
  late String emergencyType;
  late int peopleCount;

  final TextEditingController noteController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    emergencyType = widget.initialEmergencyType;
    peopleCount = widget.initialPeopleCount < 1
        ? 1
        : widget.initialPeopleCount;
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  void submitForm() {
    widget.onSubmit(
      emergencyType,
      peopleCount,
      noteController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Send SOS',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            const Text('Emergency Type'),

            DropdownButtonFormField<String>(
              value: emergencyType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'FIRE',
                  child: Text('Fire'),
                ),
                DropdownMenuItem(
                  value: 'DROWNING',
                  child: Text('Drowning'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    emergencyType = value;
                  });
                }
              },
            ),

            const SizedBox(height: 20),

            const Text('Number of People'),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: peopleCount > 1
                      ? () {
                          setState(() {
                            peopleCount--;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),

                Text(
                  '$peopleCount',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                IconButton(
                  onPressed: () {
                    setState(() {
                      peopleCount++;
                    });
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Text('Additional Note (Optional)'),

            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Describe the emergency...',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              child: const Text(
                'SUBMIT SOS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
