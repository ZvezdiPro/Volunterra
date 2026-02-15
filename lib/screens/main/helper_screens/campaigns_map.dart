import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/widgets/campaign_details_screen.dart'; 
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
  final LatLng _center = const LatLng(43.217152, 27.939351); 

  @override
  void initState() {
    super.initState();
    _generateMarkers();
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
            target: _center,
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