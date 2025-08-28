import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Controller/selfinformation_controller.dart';
import '../Controller/theme_controller.dart';
import '../routes/routes.dart';
import '../utils/dashboard_tiles.dart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final CompanyController _companyController = Get.find<CompanyController>();

  // Animation controllers for the main screen content
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // NEW: Animation controllers for the Drawer content
  late AnimationController _drawerAnimationController;
  late Animation<Offset> _drawerSlideAnimation;
  late Animation<double> _drawerFadeAnimation;

  @override
  void initState() {
    super.initState();

    // Call the fetchAndStoreCompanyName method to get the company name
    // A placeholder userName is used since it is not being passed to the function
    // _companyController.fetchAndStoreCompanyName('');

    // Initialize main screen animation controller with reduced duration
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Define main screen slide animation with less movement
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // Define main screen fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    // Start the main screen animation when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });

    // Initialize Drawer animation controller with reduced duration
    _drawerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _drawerSlideAnimation = Tween<Offset>(
      begin: const Offset(-0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _drawerAnimationController,
      curve: Curves.easeOut,
    ));
    _drawerFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _drawerAnimationController,
      curve: Curves.easeIn,
    ));

    // Trigger drawer animation after a slight delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _drawerAnimationController.forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _drawerAnimationController.dispose();
    super.dispose();
  }

  /// Navigate via **named route** so bindings fire
  void navigateTo(String route) => Get.toNamed(route);

  // _buildGridItem: Optimized for better performance
  Widget _buildGridItem(
      String label,
      IconData icon,
      VoidCallback onTap,
      BuildContext context,
      int index,
      ) {
    final itemSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        (0.1 + index * 0.05).clamp(0.0, 0.8),
        1.0,
        curve: Curves.easeOut,
      ),
    ));

    final itemFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        (0.1 + index * 0.05).clamp(0.0, 0.8),
        1.0,
        curve: Curves.easeIn,
      ),
    ));

    return FadeTransition(
      opacity: itemFadeAnimation,
      child: SlideTransition(
        position: itemSlideAnimation,
        child: GestureDetector(
          onTap: onTap,
          child: Card(
            color: Theme.of(context).cardColor,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Updated _buildDrawerItem to include staggered animation
  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, BuildContext context, int index) {
    final itemSlideAnimation = Tween<Offset>(
      begin: const Offset(-0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _drawerAnimationController,
      curve: Interval(
        (0.0 + index * 0.08).clamp(0.0, 1.0),
        1.0,
        curve: Curves.easeOutCubic,
      ),
    ));

    final itemFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _drawerAnimationController,
      curve: Interval(
        (0.0 + index * 0.08).clamp(0.0, 1.0),
        1.0,
        curve: Curves.easeIn,
      ),
    ));

    return FadeTransition(
      opacity: itemFadeAnimation,
      child: SlideTransition(
        position: itemSlideAnimation,
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).iconTheme.color),
          title: Text(title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          onTap: () {
            if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
              _scaffoldKey.currentState?.openEndDrawer();
            }
            Future.delayed(const Duration(milliseconds: 200), () {
              onTap();
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: FadeTransition(
          opacity: _drawerFadeAnimation,
          child: SlideTransition(
            position: _drawerSlideAnimation,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ClipPath(
                    clipper: WaveClipper(),
                    child: DrawerHeader(
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage("assets/appbarimg.png"),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child:  Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            // ⬅ CORRECTED LINE
                            child: Icon(Icons.person, size: 30, color: Theme.of(context).primaryColor),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: // In your HomeScreen build method, update the company name display:
                            Obx(() => Text(
                              _companyController.companyName.value,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.end,
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ...drawerTiles.asMap().entries.map((entry) {
                    final index = entry.key;
                    final t = entry.value;
                    if (t.label == 'Dashboard') {
                      return _buildDrawerItem(
                          dashIcon(t.label), t.label, () {}, context, index);
                    }
                    if (t.label == 'Profile') {
                      return _buildDrawerItem(
                          dashIcon(t.label),
                          t.label,
                              () => navigateTo(Routes.profile),
                          context,
                          index);
                    }
                    return _buildDrawerItem(
                      dashIcon(t.label),
                      t.label,
                          () => t.route.isNotEmpty ? navigateTo(t.route) : {},
                      context,
                      index,
                    );
                  }),

                  Obx(() => SwitchListTile(
                    title: Text(
                      themeController.isDarkMode.value ? "Dark Mode" : "Light Mode",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    secondary: Icon(
                      themeController.isDarkMode.value ? Icons.dark_mode : Icons.light_mode,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    value: themeController.isDarkMode.value,
                    onChanged: (bool value) {
                      themeController.toggleTheme();
                    },
                    activeColor: Theme.of(context).primaryColor,
                  )),
                  const Divider(),
                  _buildDrawerItem(Icons.logout, "Logout", () async {
                    Get.offAllNamed(Routes.login);
                  }, context, drawerTiles.length),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipPath(
                clipper: WaveClipper(),
                child: Container(
                  height: 310,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/appbarimg.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.menu, color: Colors.white),
                                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                              ),
                              const Spacer(),
                              Expanded(
                                flex: 3,
                                child: Obx(() => Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _companyController.companyName.value.isEmpty
                                          ? 'Loading ...'
                                          : _companyController.companyName.value,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.end,
                                      softWrap: true,
                                    ),
                                    const Text(
                                      "By Manabh",
                                      style: TextStyle(color: Colors.white, fontSize: 14),
                                      textAlign: TextAlign.end,
                                    ),
                                  ],
                                )),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height:150),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: dashTiles.length,
                          itemBuilder: (context, index) {
                            final t = dashTiles[index];
                            return _buildGridItem(
                              t.label,
                              dashIcon(t.label),
                                  () => t.route.isNotEmpty ? navigateTo(t.route) : {},
                              context,
                              index,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]),
    );
  }
}

class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(size.width * .25, size.height, size.width * .5, size.height - 30);
    path.quadraticBezierTo(size.width * .75, size.height - 60, size.width, size.height - 30);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
