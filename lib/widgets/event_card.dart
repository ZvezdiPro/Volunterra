import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/screens/main/helper_screens/campaign_details_screen.dart';
import 'package:volunteer_app/shared/colors.dart';

class CampaignCard extends StatefulWidget {
  
  final Campaign campaign;
  final bool showRegisterButton;
  const CampaignCard({super.key, required this.campaign, this.showRegisterButton = true});

  @override
  State<CampaignCard> createState() => _CampaignCardState();
}

class _CampaignCardState extends State<CampaignCard> {
  // Helper method to format the date
  String _formatDate(DateTime date) {
    final formatter = DateFormat('d. MMM y', 'bg_BG');
    return formatter.format(date);
  }

  // Helper method to build an icon with text
  Widget _buildIconAndText(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min, 
      children: [
        Icon(icon, size: 16.0, color: color),
        SizedBox(width: 4.0),
        Flexible(
          child: Text(
            text, 
            style: TextStyle(fontSize: 14.0, color: Colors.black),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8.0),
      // The InkWell widget provides a clickable area for the card
      child: Card(
        margin: EdgeInsets.fromLTRB(20.0, 6.0, 20.0, 0.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: InkWell(
          onTap: () => {
            // Handle card tap and create (and push) a Campaign details page
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CampaignDetailsScreen(
                    campaign: widget.campaign,
                    showRegisterButton: widget.showRegisterButton,
                  ),
                ),
              )
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Campaign image
              if (widget.campaign.imageUrl.isNotEmpty)
              // Show the image from the URL only if there is one
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8.0),
                  topRight: Radius.circular(8.0),
                ),
                child: AspectRatio(
                  aspectRatio: 19 / 9, 
                  child: Image.network(
                    widget.campaign.imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(color: greenPrimary),
                      );
                    },
                    // Error placeholder if the image fails to load
                    errorBuilder: (context, error, stackTrace) => 
                      Container(
                        color: Colors.red[100],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 40.0, color: Colors.red),
                            SizedBox(height: 8.0),
                            Text('Грешка при зареждане на изображението', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ),
                ),
              ),

              // Example placeholder for when there is no image URL
              // ClipRRect(
              //   borderRadius: BorderRadius.only(
              //     topLeft: Radius.circular(8.0),
              //     topRight: Radius.circular(8.0),
              //   ),
              //   child: AspectRatio(
              //     aspectRatio: 19 / 9, 
              //     child: Container(
              //       color: Colors.grey[200],
              //       child: Center(
              //         child: Column(
              //           mainAxisAlignment: MainAxisAlignment.center,
              //           children: [
              //             Icon(
              //               Icons.photo_library,
              //               size: 40.0, 
              //               color: Colors.grey[500]
              //             ),
              //             SizedBox(height: 8.0),
              //             Text('Няма качено изображение', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
              //           ],
              //         ),
              //       ),
              //     ),
              //   ),
              // ),
              
              // Campaign details
              // (wrapped with padding for spacing between the text and the card edges)
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Campaign title
                    Text(
                      widget.campaign.title,
                      style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    SizedBox(height: 8.0),
                    
                    // Row with location, date and required volunteers
                    Wrap(
                      spacing: 16.0,
                      runSpacing: 8.0,
                      children: <Widget>[
                        _buildIconAndText(Icons.location_on, widget.campaign.location, greenPrimary),
                        _buildIconAndText(Icons.calendar_today, _formatDate(widget.campaign.startDate), greenPrimary),
                        _buildIconAndText(Icons.group, '${widget.campaign.registeredVolunteersUids.length}/${widget.campaign.requiredVolunteers} записани', greenPrimary),
                      ],
                    ),
                  ],
                ),
              )

            ]
          ),
        ),
      ),
    );
  }
}