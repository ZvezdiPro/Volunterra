import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:volunteer_app/shared/colors.dart';

class MapPickerScreen extends StatefulWidget {
  // If the user is already editing an existing location we can pass initial coordinates
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({
    super.key, 
    this.initialLat, 
    this.initialLng
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // The coordinates at the center of the camera
  late LatLng _currentCenter;
  bool _isLoadingAddress = false;

  // ignore: unused_field
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    // Set initial center using either the provided coordinates or a default location
    // The default location coordinates are defined in CampaignData model
    _currentCenter = LatLng(widget.initialLat!, widget.initialLng!);
  }

  void _onCameraMove(CameraPosition position) {
    _currentCenter = position.target;
  }

  // Logic to convert the coordinates to a readable address
  Future<void> _pickLocation() async {
    setState(() => _isLoadingAddress = true);

    try {
      // Reverse Geocoding: Get address from Lat/Lng
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentCenter.latitude,
        _currentCenter.longitude,
      );

      String addressString = 'Неизвестна локация';

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        // Restrict to Bulgaria
        if (place.isoCountryCode != 'BG') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const SizedBox(
                  height: 60,
                  child: Center(
                    child: Text(
                      'Кампаниите могат да се провеждат само в България!',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        addressString = 'Неизвестна локация';
        final street = place.thoroughfare ?? '';
        final number = place.subThoroughfare ?? '';
        final city = place.locality ?? '';
        
        if (street.isNotEmpty) {
          addressString = '$street $number, $city';
        } else {
          addressString = city;
        }
      }

      // Return the data to the previous screen
      if (mounted) {
        Navigator.pop(context, {
          'latitude': _currentCenter.latitude,
          'longitude': _currentCenter.longitude,
          'address': addressString,
        });
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Грешка при намиране на адрес: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Избери локация', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: greenPrimary,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // The Map
            GoogleMap(
              padding: EdgeInsets.only(bottom: 90.0),
              initialCameraPosition: CameraPosition(
                target: _currentCenter,
                zoom: 15,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onCameraMove: _onCameraMove,
              myLocationEnabled: true, // Shows blue dot if permission is granted
              myLocationButtonEnabled: true,
              mapToolbarEnabled: false, // Hides the "Open in Maps" buttons
            ),
        
            // The Pin (Always in the center)
            Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 40.0),
                child: Icon(
                  Icons.location_on, 
                  size: 50, 
                  color: Colors.redAccent
                ),
              ),
            ),
        
            // The "Pick Here" Button
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoadingAddress ? null : _pickLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: greenPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoadingAddress 
                    ? SizedBox(
                        height: 24, 
                        width: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : Text(
                        'Потвърди локацията', 
                        style: TextStyle(fontSize: 18, color: Colors.white)
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}