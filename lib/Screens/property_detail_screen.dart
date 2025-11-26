import 'dart:ui';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
// ✅ 1. 引入全景图查看包
import 'package:panorama_viewer/panorama_viewer.dart'; 
import 'package:smart_rental_system/screens/add_property_screen.dart';

import '../Compoents/favorite_button.dart';
import '../Compoents/glass_card.dart';
import '../Compoents/landlord_contact_card.dart';
import '../Compoents/property_display_widgets.dart';
import '../Screens/login_screen.dart'; 


class PropertyDetailScreen extends StatefulWidget {
  final String propertyId; 

  const PropertyDetailScreen({super.key, required this.propertyId});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  late Stream<DocumentSnapshot> _propertyStream;
  
  static const LatLng _defaultFallbackLatLng = LatLng(3.1390, 101.6869); // 吉隆坡坐标

  @override
  void initState() {
    super.initState();
    _propertyStream = FirebaseFirestore.instance
        .collection('properties')
        .doc(widget.propertyId)
        .snapshots();
  }

  void _openFullScreenImageViewer(List<String> imageUrls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
  
  // ✅ 打开全屏 360 查看器
  void _openFullScreen360(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              PanoramaViewer(
                sensorControl: SensorControl.orientation, // 开启陀螺仪
                child: Image.network(imageUrl),
              ),
              Positioned(
                top: 40,
                left: 20,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _sendBookingRequest({
    required String landlordUid,
    required String tenantUid,
    required String propertyId,
    required DateTime meetingTime,
    required String communityName, 
  }) async {
    try {
      await FirebaseFirestore.instance.collection('bookings').add({
        'propertyId': propertyId,
        'landlordUid': landlordUid,
        'tenantUid': tenantUid,
        'meetingTime': Timestamp.fromDate(meetingTime),
        'meetingPoint': communityName, 
        'status': 'pending', 
        'requestedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to send request: $e');
    }
  }

  // ✅ 优化后的玻璃 Dialog：紧贴内容，无多余留白
  Widget _buildGlassDialog(BuildContext context, Widget? child) {
    const Color primaryBlue = Color(0xFF1D5DC7);

    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: primaryBlue,
          onPrimary: Colors.white,
          onSurface: Colors.white,
          surface: Colors.transparent, 
        ),
        dialogBackgroundColor: Colors.transparent,
        
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white, 
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
        
        timePickerTheme: TimePickerThemeData(
          backgroundColor: Colors.transparent,
          dialBackgroundColor: Colors.white.withOpacity(0.15),
          dialHandColor: primaryBlue,
          dialTextColor: Colors.white,
          hourMinuteColor: MaterialStateColor.resolveWith((states) =>
            states.contains(MaterialState.selected)
                ? primaryBlue.withOpacity(0.5) 
                : Colors.white.withOpacity(0.1)),
          hourMinuteTextColor: Colors.white,
          dayPeriodColor: MaterialStateColor.resolveWith((states) =>
             states.contains(MaterialState.selected) ? primaryBlue : Colors.transparent),
          dayPeriodTextColor: MaterialStateColor.resolveWith((states) =>
             states.contains(MaterialState.selected) ? Colors.white : Colors.white70),
          dayPeriodBorderSide: const BorderSide(color: Colors.white30),
          inputDecorationTheme: InputDecorationTheme(
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white30),
            ),
          ),
        ),
        
        datePickerTheme: DatePickerThemeData(
          backgroundColor: Colors.transparent,
          headerBackgroundColor: primaryBlue,
          headerForegroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          dayOverlayColor: MaterialStateProperty.all(primaryBlue.withOpacity(0.3)),
          // 减小默认圆角
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            // ✅ 关键：只给左右留一点边距，不给上下留
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              // ✅ 高亮渐变
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.45),
                  Colors.white.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                // ✅ 关键：去除所有 Padding 和 Flexible，紧贴内容
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    child ?? const SizedBox(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 底部弹窗：输入框变“瘦”了
  void _showBookingSheet(BuildContext context, String landlordUid, String communityName) {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
                  left: 20, right: 20, top: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.45),
                      Colors.white.withOpacity(0.15),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Schedule a Viewing',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    InputDecorator(
                      decoration: _bookingInputDecoration(Icons.location_on_outlined, 'Meeting Point'),
                      child: Text(
                        communityName,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 12), // 减小间距
                    
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 1)), 
                                firstDate: DateTime.now().add(const Duration(days: 1)), 
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                                builder: (context, child) => _buildGlassDialog(context, child),
                              );
                              if (pickedDate != null) {
                                setModalState(() {
                                  selectedDate = pickedDate;
                                });
                              }
                            },
                            child: InputDecorator(
                              // 这里调用了变瘦后的 Decoration
                              decoration: _bookingInputDecoration(Icons.calendar_today, 'Date'),
                              child: Text(
                                selectedDate == null ? 'Select Date' : DateFormat('dd/MM/yyyy').format(selectedDate!),
                                style: TextStyle(color: selectedDate == null ? Colors.white70 : Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final TimeOfDay? pickedTime = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                                builder: (context, child) => _buildGlassDialog(context, child),
                              );
                              if (pickedTime != null) {
                                setModalState(() {
                                  selectedTime = pickedTime;
                                });
                              }
                            },
                            child: InputDecorator(
                              // 这里调用了变瘦后的 Decoration
                              decoration: _bookingInputDecoration(Icons.access_time, 'Time'),
                              child: Text(
                                selectedTime == null ? 'Select Time' : selectedTime!.format(context),
                                style: TextStyle(color: selectedTime == null ? Colors.white70 : Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D5DC7),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 5,
                        shadowColor: const Color(0xFF1D5DC7).withOpacity(0.4),
                      ),
                      onPressed: isSubmitting ? null : () async {
                        if (selectedDate == null || selectedTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a date and time.'), backgroundColor: Colors.redAccent),
                          );
                          return;
                        }
                        
                        setModalState(() => isSubmitting = true);
                        
                        try {
                          final DateTime fullMeetingTime = DateTime(
                            selectedDate!.year, selectedDate!.month, selectedDate!.day,
                            selectedTime!.hour, selectedTime!.minute,
                          );
                          
                          await _sendBookingRequest(
                            landlordUid: landlordUid,
                            tenantUid: FirebaseAuth.instance.currentUser!.uid,
                            propertyId: widget.propertyId,
                            meetingTime: fullMeetingTime,
                            communityName: communityName, 
                          );
                          
                          Navigator.pop(context); 
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ Viewing request sent!'), backgroundColor: Colors.green),
                          );
                          
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                          );
                        } finally {
                          if (mounted) {
                              setModalState(() => isSubmitting = false);
                          }
                        }
                      },
                      child: isSubmitting 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text('Send Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _propertyStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Error: ${snapshot.error ?? "Property not found"}', style: const TextStyle(color: Colors.white70)));
          }

          final propertyData = snapshot.data!.data() as Map<String, dynamic>;
          final List<String> imageUrls = List<String>.from(propertyData['imageUrls'] ?? []);
          final String? url360 = propertyData['360ImageUrl'];
          
          final String communityName = propertyData['communityName'] ?? 'N/A';
          final String unitNumber = propertyData['unitNumber'] ?? 'N/A';
          final String floor = propertyData['floor'] ?? 'N/A';
          final String address = "Unit $unitNumber, Floor $floor, $communityName"; 
          final String title = communityName; 
          final String landlordUid = propertyData['landlordUid'] ?? '';
          final double rent = (propertyData['price'] as num?)?.toDouble() ?? 0.0;
          final String description = propertyData['description'] ?? 'N/A';
          final int bedrooms = propertyData['bedrooms'] ?? 0;
          final int bathrooms = propertyData['bathrooms'] ?? 0;
          final int parking = propertyData['parking'] ?? 0;
          final int airConditioners = propertyData['airConditioners'] ?? 0;
          final String furnishing = propertyData['furnishing'] ?? 'N/A';
          final String size = propertyData['size_sqft'] ?? 'N/A';
          final List<String> facilities = List<String>.from(propertyData['facilities'] ?? []);
          final List<String> features = List<String>.from(propertyData['features'] ?? []);
          final Timestamp? availableDateTimestamp = propertyData['availableDate'];
          final String availableDate = availableDateTimestamp != null
              ? DateFormat('yyyy-MM-dd').format(availableDateTimestamp.toDate())
              : 'N/A';
          
          final double lat = (propertyData['latitude'] as num?)?.toDouble() ?? _defaultFallbackLatLng.latitude; 
          final double lng = (propertyData['longitude'] as num?)?.toDouble() ?? _defaultFallbackLatLng.longitude; 
          final LatLng propertyLocation = LatLng(lat, lng);
          
          final Set<Marker> markers = {
            Marker(
              markerId: MarkerId(widget.propertyId),
              position: propertyLocation,
              infoWindow: InfoWindow(title: communityName),
            ),
          };
          
          final currentUser = FirebaseAuth.instance.currentUser;
          final bool isLandlord = currentUser != null && landlordUid == currentUser.uid;

          return Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF153a44),
                      Color(0xFF295a68),
                      Color(0xFF5d8fa0),
                      Color(0xFF94bac4),
                    ],
                  ),
                ),
              ),
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: MediaQuery.of(context).size.height * 0.3,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: Colors.white),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Hero(
                        tag: widget.propertyId,
                        child: _ImageCarousel(
                          imageUrls: imageUrls,
                          onImageTap: (index) => _openFullScreenImageViewer(imageUrls, index),
                        ),
                      ),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: FavoriteButton(propertyId: widget.propertyId),
                      ),

                      if (isLandlord)
                        Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddPropertyScreen(propertyId: widget.propertyId),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  SliverList(
                    delegate: SliverChildListDelegate([
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (landlordUid.isNotEmpty) ...[
                              LandlordContactCard(
                                landlordUid: landlordUid,
                                currentUserId: currentUser?.uid,
                              ),
                              const SizedBox(height: 16),
                            ],
                            GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text(address, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'RM ${rent.toStringAsFixed(0)} / Month',
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 22, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      if (bedrooms > 0) InfoChip(icon: Icons.king_bed_outlined, label: '$bedrooms Beds'),
                                      if (bathrooms > 0) InfoChip(icon: Icons.bathtub_outlined, label: '$bathrooms Baths'),
                                      if (parking > 0) InfoChip(icon: Icons.local_parking_outlined, label: '$parking Parking'),
                                      if (airConditioners > 0) InfoChip(icon: Icons.ac_unit, label: '$airConditioners AC'),
                                      if (size.isNotEmpty) InfoChip(icon: Icons.square_foot, label: '$size sqft'),
                                    ],
                                  ),
                                  const Divider(color: Colors.white30, height: 32),
                                  _buildDetailRow(Icons.chair, 'Furnishing', furnishing),
                                  _buildDetailRow(Icons.calendar_today, 'Available Date', availableDate),
                                ],
                              ),
                            ),
                            
                            // 360 全景图展示区域
                            if (url360 != null && url360.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildSectionTitle('360° Virtual Tour'),
                                        IconButton(
                                          icon: const Icon(Icons.fullscreen, color: Colors.white),
                                          onPressed: () => _openFullScreen360(url360),
                                          tooltip: "Full Screen",
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        height: 250, // 预览区域高度
                                        child: Stack(
                                          children: [
                                            PanoramaViewer(
                                              // 开启陀螺仪
                                              sensorControl: SensorControl.orientation,
                                              child: Image.network(url360),
                                            ),
                                            // 提示遮罩
                                            Positioned(
                                              bottom: 10,
                                              right: 10,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(Icons.threesixty, color: Colors.white, size: 16),
                                                    SizedBox(width: 4),
                                                    Text("Move phone to look around", style: TextStyle(color: Colors.white, fontSize: 10)),
                                                  ],
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),
                            if (description.isNotEmpty) ...[
                              GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle('Description'),
                                    const SizedBox(height: 8),
                                    Text(description, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (features.isNotEmpty || facilities.isNotEmpty)
                              GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (features.isNotEmpty) ...[
                                      _buildSectionTitle('Property Features'),
                                      const SizedBox(height: 12),
                                      _buildFacilitiesGrid(features, isFeature: true),
                                      if (facilities.isNotEmpty) const Divider(color: Colors.white30, height: 32),
                                    ],
                                    if (facilities.isNotEmpty) ...[
                                      _buildSectionTitle('Facilities'),
                                      const SizedBox(height: 12),
                                      _buildFacilitiesGrid(facilities, isFeature: false),
                                    ],
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('Location'),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 250,
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                                    clipBehavior: Clip.antiAlias,
                                    child: GoogleMap(
                                      mapType: MapType.normal,
                                      initialCameraPosition: CameraPosition(
                                        target: propertyLocation,
                                        zoom: 14.0,
                                      ),
                                      markers: markers,
                                      scrollGesturesEnabled: false,
                                      zoomGesturesEnabled: false,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: StreamBuilder<DocumentSnapshot>(
        stream: _propertyStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final propertyData = (snapshot.data!.data() ?? {}) as Map<String, dynamic>;
          final String landlordUid = propertyData['landlordUid'] ?? '';
          
          final String communityName = propertyData['communityName'] ?? 'N/A';
          
          final currentUser = FirebaseAuth.instance.currentUser;
          final bool isLandlord = currentUser != null && landlordUid == currentUser.uid;
          if (isLandlord) {
            return const SizedBox.shrink();
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (currentUser == null) {
                          _navigateToLogin();
                        } else {
                          _showBookingSheet(context, landlordUid, communityName);
                        }
                      },
                      icon: Icon(currentUser == null ? Icons.login : Icons.calendar_month, color: Colors.white),
                      label: Text(
                        currentUser == null ? 'Login to Schedule Viewing' : 'Schedule a viewing',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D5DC7),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white70),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilitiesGrid(List<String> items, {bool isFeature = false}) {
    if (items.isEmpty) {
      return Text(isFeature ? "No features listed." : "No facilities listed.", style: const TextStyle(color: Colors.white70));
    }
    return Column( 
      children: items.map((item) {
        return FeatureListItem( 
          label: item,
          icon: isFeature ? _getFeatureIcon(item) : _getFacilityIcon(item),
        );
      }).toList(),
    );
  }

  IconData _getFacilityIcon(String facility) {
    final Map<String, IconData> iconMap = {
      '24-hour security': Icons.security,
      'free indoor gym': Icons.fitness_center,
      'free outdoor pool': Icons.pool,
      'parking area': Icons.local_parking,
      'playground': Icons.child_friendly, 
      'garden': Icons.eco,
      'elevator': Icons.elevator,
    };
    return iconMap[facility.toLowerCase()] ?? Icons.check_circle_outline; 
  }

  IconData _getFeatureIcon(String feature) {
      final Map<String, IconData> iconMap = {
      'balcony': Icons.balcony,
      'air conditioner': Icons.ac_unit, 
      'water heater': Icons.water_drop,
      'washing machine': Icons.local_laundry_service,
      'refrigerator': Icons.kitchen,
      'microwave': Icons.microwave,
      'oven': Icons.outdoor_grill, 
      'dishwasher': Icons.wash, 
      'tv': Icons.tv,
      'internet': Icons.wifi,
      'study desk': Icons.desk,
      'wardrobe': Icons.checkroom, 
    };
    return iconMap[feature.toLowerCase()] ?? Icons.check_circle_outline; 
  }
  
  // ✅ 核心调整：InputDecorator 变瘦了
  InputDecoration _bookingInputDecoration(IconData icon, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70, size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      // isDense: true 减少默认高度
      isDense: true, 
      // contentPadding 减小内边距，让盒子变矮
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
    );
  }
}

// ===============================================================
// 【图片轮播器】
// ===============================================================
class _ImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final Function(int) onImageTap;

  const _ImageCarousel({required this.imageUrls, required this.onImageTap});

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  int _currentImageIndex = 0; 

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.3,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.white54, size: 60),
        ),
      );
    }
    
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: CarouselSlider.builder(
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index, realIndex) {
              return GestureDetector( 
                onTap: () => widget.onImageTap(index), 
                child: Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.cover,
                  width: MediaQuery.of(context).size.width,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                ),
              );
            },
            options: CarouselOptions(
              height: MediaQuery.of(context).size.height * 0.3, 
              autoPlay: true,
              viewportFraction: 1.0,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentImageIndex = index; 
                });
              },
            ),
          ),
        ),
        // 小圆点指示器
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: widget.imageUrls.asMap().entries.map((entry) {
            return Container(
              width: 8.0,
              height: 8.0,
              margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (Colors.white) 
                    .withOpacity(_currentImageIndex == entry.key ? 0.9 : 0.4),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ===============================================================
// 【全屏图片查看器】
// ===============================================================
class FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8), 
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index; 
          });
        },
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer( 
              panEnabled: true, 
              minScale: 0.8,
              maxScale: 4.0,
              child: Image.network(
                widget.imageUrls[index],
                fit: BoxFit.contain, 
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}