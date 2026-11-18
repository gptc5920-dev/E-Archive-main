part of '../../dashboard_shell_page.dart';

// Sidebar palette matching the dark navy reference UI.
const _sidebarBg = Color(0xFF12253A);
const _sidebarBorder = Color(0xFF1E334A);
const _sidebarHeading = Color(0xFF8EA2B8);
const _sidebarItem = Color(0xFFC8D2DE);
const _sidebarHoverBg = Color(0xFF1B3048);
const _sidebarActiveBg = Color(0xFF243C5F);
const _sidebarActive = Color(0xFFF8FAFC);
const _sidebarActiveDarkBg = Color(0xFF243C5F);
const _sidebarAccent = Color(0xFFFBBF24);
const _sidebarBadge = Color(0xFFF04438);
const _sidebarExpandedWidth = 280.0;
const _sidebarCollapsedWidth = 68.0;
const _sidebarAnimDuration = Duration(milliseconds: 240);
const _sidebarAnimCurve = Curves.easeOutCubic;

TextStyle _sidebarText({
  required double size,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return AppFonts.poppins(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}
