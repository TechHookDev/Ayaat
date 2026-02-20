import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/language_service.dart';
import 'home_screen.dart';

class UpdateSplashScreen extends StatefulWidget {
  const UpdateSplashScreen({super.key});

  @override
  State<UpdateSplashScreen> createState() => _UpdateSplashScreenState();
}

class _UpdateSplashScreenState extends State<UpdateSplashScreen> {
  final LanguageService _languageService = LanguageService();
  AppLanguage _currentLanguage = AppLanguage.arabic;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final lang = await _languageService.getCurrentLanguage();
    setState(() {
      _currentLanguage = lang;
    });
  }

  Future<void> _dismissSplash() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_v109_splash', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _currentLanguage == AppLanguage.arabic;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A237E), Color(0xFF0D1B2A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: Column(
              children: [
                const Spacer(),
                // Celebratory Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFFFD700),
                    size: 64,
                  ),
                ),
                const SizedBox(height: 40),
                // Heading
                Text(
                  isArabic ? 'تحديث آيات الجديد' : 'Ayaat Update',
                  style: GoogleFonts.amiri(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFD700),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isArabic ? 'إصدار 1.0.9' : 'Version 1.0.9',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.white54,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 50),
                
                // Feature List
                _buildFeatureRow(
                  icon: Icons.local_fire_department,
                  title: isArabic ? 'نظام النقاط والمواظبة' : 'Daily Streak & Points',
                  desc: isArabic 
                      ? 'بناء عادة يومية وتتبع قراءتك مع نظام النقاط الجديد' 
                      : 'Build a daily habit and track your progress with our new points system.',
                ),
                const SizedBox(height: 30),
                _buildFeatureRow(
                  icon: Icons.menu_book,
                  title: isArabic ? 'المصحف' : 'Mushaf',
                  desc: isArabic 
                      ? 'الاستماع لتلاوة الآيات بصوت نقي وحفظ موضع القراءة بسلاسة' 
                      : 'Listen to clear audio recitations and save your progress seamlessly.',
                ),
                const SizedBox(height: 30),
                _buildFeatureRow(
                  icon: Icons.text_fields,
                  title: isArabic ? 'تحكم في حجم الخط' : 'Adjustable Font Size',
                  desc: isArabic 
                      ? 'تكبير وتصغير حجم الخط لراحة عينيك أثناء القراءة الاستثنائية' 
                      : 'Increase or decrease the font size for a comfortable reading experience.',
                ),
                
                const Spacer(),
                
                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _dismissSplash,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: const Color(0xFF0D1B2A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      isArabic ? 'ابدأ القراءة' : 'Start Reading',
                      style: GoogleFonts.amiri(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({required IconData icon, required String title, required String desc}) {
    final isArabic = _currentLanguage == AppLanguage.arabic;
    
    return Row(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFFFD700), size: 24),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.amiri(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: GoogleFonts.amiri(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.4,
                ),
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
