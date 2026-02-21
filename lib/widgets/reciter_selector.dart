import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/reciter.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';

/// Widget for selecting a Quran reciter
class ReciterSelector extends StatelessWidget {
  final AudioService audioService;
  final AppLanguage language;
  final VoidCallback? onReciterChanged;

  const ReciterSelector({
    super.key,
    required this.audioService,
    required this.language,
    this.onReciterChanged,
  });

  String _getReciterDisplayName(Reciter reciter) {
    return reciter.getDisplayName(language);
  }

  void _showReciterPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A237E).withOpacity(0.95),
                const Color(0xFF0D47A1).withOpacity(0.95),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: const Color(0xFFFFD700).withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                language == AppLanguage.arabic ? 'اختر القارئ' : 'Select Reciter',
                style: GoogleFonts.amiri(
                  color: const Color(0xFFFFD700),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: Reciters.all.length,
                  itemBuilder: (context, index) {
                    final reciter = Reciters.all[index];
                    final isSelected = audioService.currentReciter == reciter;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 4,
                      ),
                      leading: isSelected
                          ? const Icon(Icons.check_circle, color: Color(0xFFFFD700))
                          : const Icon(Icons.circle_outlined, color: Colors.white24),
                      title: Text(
                        _getReciterDisplayName(reciter),
                        style: GoogleFonts.amiri(
                          color: isSelected ? const Color(0xFFFFD700) : Colors.white,
                          fontSize: 18,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: language == AppLanguage.arabic
                            ? TextAlign.right
                            : TextAlign.left,
                      ),
                      onTap: () {
                        audioService.setReciter(reciter);
                        onReciterChanged?.call();
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showReciterPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A237E).withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFD700).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.person_pin_rounded,
              color: Color(0xFFFFD700),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _getReciterDisplayName(audioService.currentReciter),
                style: GoogleFonts.amiri(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFFFFD700),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
