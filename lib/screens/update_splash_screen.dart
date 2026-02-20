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

class _UpdateSplashScreenState extends State<UpdateSplashScreen> with SingleTickerProviderStateMixin {
  final LanguageService _languageService = LanguageService();
  AppLanguage _currentLanguage = AppLanguage.arabic;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadLanguage() async {
    final language = await _languageService.getCurrentLanguage();
    setState(() {
      _currentLanguage = language;
    });
  }

  Future<void> _finishSplash() async {
    final prefs = await SharedPreferences.getInstance();
    // Mark as seen so they don't see it again until the next major feature
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
    final isFrench = _currentLanguage == AppLanguage.french;
    
    final titleText = isArabic ? 'ما الجديد في آيات' : (isFrench ? 'Quoi de neuf dans Ayaat' : 'What\'s New in Ayaat');
    final subtitleText = isArabic ? 'تعرف على ميزاتنا الجديدة الرائعة' : (isFrench ? 'Découvrez nos nouvelles fonctionnalités' : 'Discover our exciting new features');
    final buttonText = isArabic ? 'متابعة' : (isFrench ? 'Continuer' : 'Continue');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A237E), Color(0xFF0D1B2A)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                const Spacer(flex: 1),
                
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star, color: Color(0xFFFFD700), size: 64),
                ),
                const SizedBox(height: 24),
                
                Text(
                  titleText,
                  style: GoogleFonts.amiri(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitleText,
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const Spacer(flex: 1),
                
                // Features List
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildFeatureRow(
                        icon: Icons.menu_book,
                        iconColor: const Color(0xFFFFD700),
                        title: isArabic ? 'المصحف المطور' : (isFrench ? 'Mushaf Premium' : 'Premium Mushaf'),
                        description: isArabic ? 'تجربة قراءة محسنة مع تحكم بحجم الخط' : (isFrench ? 'Expérience de lecture avec contrôle de la taille de la police' : 'Enhanced reading experience with scalable fonts'),
                      ),
                      const SizedBox(height: 24),
                      _buildFeatureRow(
                        icon: Icons.play_circle_fill,
                        iconColor: Colors.greenAccent,
                        title: isArabic ? 'التلاوة الصوتية' : (isFrench ? 'Récitation Audio' : 'Audio Recitation'),
                        description: isArabic ? 'استمع إلى تلاوة أي آية فوراً' : (isFrench ? 'Écoutez la récitation de chaque verset' : 'Listen to the recitation of any verse instantly'),
                      ),
                      const SizedBox(height: 24),
                      _buildFeatureRow(
                        icon: Icons.local_fire_department,
                        iconColor: Colors.orange,
                        title: isArabic ? 'الأهداف والإحصائيات' : (isFrench ? 'Objectifs et Statistiques' : 'Streaks & Stats'),
                        description: isArabic ? 'تابع تقدمك وحافظ على وردك اليومي' : (isFrench ? 'Suivez vos progrès et maintenez votre série' : 'Track your reading progress and build a daily habit'),
                      ),
                      const SizedBox(height: 24),
                      _buildFeatureRow(
                        icon: Icons.bookmark,
                        iconColor: Colors.lightBlueAccent,
                        title: isArabic ? 'العلامات المرجعية' : (isFrench ? 'Signets Intelligents' : 'Smart Bookmarks'),
                        description: isArabic ? 'احفظ موضع قراءتك وتابع لاحقاً بسهولة' : (isFrench ? 'Sauvegardez votre position de lecture' : 'Save your spot and resume reading easily'),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(flex: 2),
                
                // Continue Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ElevatedButton(
                    onPressed: _finishSplash,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: const Color(0xFF1A237E),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      minimumSize: const Size(double.infinity, 56),
                      elevation: 8,
                    ),
                    child: Text(
                      buttonText,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
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

  Widget _buildFeatureRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    final isArabic = _currentLanguage == AppLanguage.arabic;
    
    return Row(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
