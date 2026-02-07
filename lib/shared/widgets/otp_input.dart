import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.controllers,
    required this.focusNodes,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  @override
  void initState() {
    super.initState();

    // 🔁 rebuild UI when focus changes
    for (final node in widget.focusNodes) {
      node.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.controllers.length, (index) {
        final isFocused = widget.focusNodes[index].hasFocus;

        return SizedBox(
          width: 46,
          height: 56,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              gradient: AppTheme.blueSurfaceGradient,
              borderRadius: BorderRadius.circular(12),
              border: isFocused
                  ? Border.all(
                      color: colors.primary,
                      width: 1.8,
                    )
                  : Border.all(
                      color: colors.onSurface.withValues(alpha: 0.15),
                      width: 1,
                    ),
            ),
            alignment: Alignment.center,
            child: TextFormField(
              controller: widget.controllers[index],
              focusNode: widget.focusNodes[index], // ✅ ONLY HERE
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              maxLength: 1,
              style: theme.textTheme.titleLarge,
              decoration: const InputDecoration(
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
              ),

              // 🚀 OTP BEHAVIOUR
              onChanged: (value) {
                // paste support
                if (value.length > 1) {
                  final chars = value.split('');
                  for (int i = 0;
                      i < chars.length &&
                          i < widget.controllers.length;
                      i++) {
                    widget.controllers[i].text = chars[i];
                  }
                  widget.focusNodes.last.requestFocus();
                  return;
                }

                // move forward
                if (value.isNotEmpty &&
                    index < widget.controllers.length - 1) {
                  widget.focusNodes[index + 1].requestFocus();
                }

                // last box → dismiss keyboard
                if (value.isNotEmpty &&
                    index == widget.controllers.length - 1) {
                  widget.focusNodes[index].unfocus();
                }
              },

              // ⬅️ BACKSPACE → previous box
              onTapOutside: (_) {
                FocusScope.of(context).unfocus();
              },
            ),
          ),
        );
      }),
    );
  }
}