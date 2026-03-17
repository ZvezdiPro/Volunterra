import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/screens/main/helper_screens/campaign_details_screen.dart'; 
import 'package:volunteer_app/shared/colors.dart';

class CampaignsMapScreen extends StatefulWidget {
  final List<Campaign> campaigns;

  const CampaignsMapScreen({super.key, required this.campaigns});

  @override
  State<CampaignsMapScreen> createState() => _CampaignsMapScreenState();
}

class _CampaignsMapScreenState extends State<CampaignsMapScreen> {
  GoogleMapController? mapController;
  Set<Marker> _markers = {};

  // The fallback center is used when we can't get the user's location (e.g., permission denied)
  // and while the method for fetching the user's location is still in progress.
  final LatLng _fallbackCenter = const LatLng(43.217152, 27.939351); 

  @override
  void initState() {
    super.initState();
    _generateMarkers();
  }

  // Get the user's current location and move the map camera there
  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 14.0,
          ),
        ),
      );
    }
  }
  
  void _generateMarkers() {
    Set<Marker> tempMarkers = {};

    for (var campaign in widget.campaigns) {
      bool isActive = campaign.status != 'ended' && !campaign.endDate.isBefore(DateTime.now());
      
      tempMarkers.add(
        Marker(
          markerId: MarkerId(campaign.id),
          position: LatLng(campaign.latitude, campaign.longitude),
          infoWindow: InfoWindow(
            title: campaign.title,
            snippet: 'Натисни тук за детайли',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CampaignDetailsScreen(
                    campaign: campaign,
                    showRegisterButton: true,
                  ),
                ),
              );
            },
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          alpha: isActive ? 1.0 : 0.8,
        ),
      );
    }

    setState(() {
      _markers = tempMarkers;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _getUserLocation();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Кампании на картата', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: backgroundGrey,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: true,
        child: GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _fallbackCenter,
            zoom: 14.0,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
        ),
      ),
    );
  }
}