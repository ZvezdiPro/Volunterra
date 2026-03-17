import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:intl/intl.dart';
import 'package:volunteer_app/shared/constants.dart';
import 'package:volunteer_app/shared/loading.dart';
import 'package:volunteer_app/screens/main/helper_screens/public_profile_screen.dart';

class CampaignDetailsScreen extends StatefulWidget {
  final Campaign campaign;
  final bool showRegisterButton;

  const CampaignDetailsScreen({
    super.key, 
    required this.campaign, 
    this.showRegisterButton = true
  });

  @override
  State<CampaignDetailsScreen> createState() => _CampaignDetailsScreenState();
}

class _CampaignDetailsScreenState extends State<CampaignDetailsScreen> {

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy', 'bg_BG').format(date);
  }

  String _formatTime(DateTime date) {
    return DateFormat('HH:mm', 'bg_BG').format(date);
  }

  Future<void> _openMap(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не може да се отвори приложението за карти.'))
          );
        }
      }
    } catch (e) {
      debugPrint("Error launching maps: $e");
    }
  }

  void _showGuestActionMessage(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.orange,
        content: Center(child: Text('Тази функция е достъпна само за регистрирани потребители!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onBookmarkTap(BuildContext context, VolunteerUser? user, bool currentStatus) async {
    if (user == null) return;

    bool newStatus = !currentStatus;
    String message = newStatus ? 'Добавено в запазени кампании' : 'Премахнато от запазени кампании';
    
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold))),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: greenPrimary,
        )
      );
    }

    try {
      await DatabaseService(uid: user.uid).toggleCampaignBookmark(widget.campaign.id, currentStatus);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Center(child: Text('Грешка при свързване с базата данни.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = Provider.of<VolunteerUser?>(context);

    if (authUser == null) {
      return const Scaffold(body: Center(child: Loading()));
    }

    final bool isGuest = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;

    return isGuest ? _buildPage(context, authUser, isBookmarked: false, isGuest: true)
    : StreamBuilder<VolunteerUser?>(
      stream: DatabaseService(uid: authUser.uid).volunteerUserData,
      builder: (context, snapshot) {
        VolunteerUser? user = snapshot.data ?? authUser;
        bool isBookmarked = user.bookmarkedCampaignsIds.contains(widget.campaign.id);
        return _buildPage(context, user, isBookmarked: isBookmarked, isGuest: isGuest);
    });
  }

  Scaffold _buildPage(BuildContext context, VolunteerUser user, {required bool isBookmarked, required bool isGuest}) {
    bool hasImage = widget.campaign.imageUrl.isNotEmpty;
    Widget? bottomButton = widget.showRegisterButton ? _buildBottomButton(user, isGuest) : null;

    return Scaffold(
      backgroundColor: backgroundGrey,
      bottomNavigationBar: bottomButton,
      
      body: SafeArea(
        top: false,
        bottom: true,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: hasImage ? 250.0 : null,
              pinned: true,
              backgroundColor: backgroundGrey,
              elevation: 0,
              centerTitle: true,
              
              // Back button
              leading: Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(200),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              
              // Save button
              actions: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(200),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        isBookmarked ? Icons.bookmark : Icons.bookmark_border, 
                        color: isBookmarked ? blueSecondary : Colors.black,
                      ),
                      onPressed: () {
                        if (isGuest) {
                          _showGuestActionMessage(context);
                        } else {
                          _onBookmarkTap(context, user, isBookmarked);
                        }
                      },
                    ),
                  ),
                ),
              ],
              
              // Flexible space with image or title
              flexibleSpace: hasImage ? FlexibleSpaceBar(
                background: Image.network(
                  widget.campaign.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                    ),
                  ),
                ),
              ) : const FlexibleSpaceBar(
                centerTitle: true,
                title: Text('Детайли за кампанията', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
              ),
            ),
        
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: backgroundGrey,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Campaign title
                      Center(
                        child: Text(
                          widget.campaign.title,
                          style: mainHeadingStyle.copyWith(fontSize: 24),
                          textAlign: TextAlign.center,
                        ),
                      ),
        
                      const SizedBox(height: 8),

                      // Organizer info
                      FutureBuilder<VolunteerUser?>(
                        future: DatabaseService(uid: widget.campaign.organizerId).getVolunteerUser(),
                        builder: (context, organizerSnapshot) {
                          if (organizerSnapshot.hasData && organizerSnapshot.data != null) {
                            final organizer = organizerSnapshot.data!;
                            return Center(
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PublicProfileScreen(volunteer: organizer),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withAlpha(25),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.blue.withAlpha(50)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.account_circle_outlined, size: 18, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Организатор: ${organizer.firstName} ${organizer.lastName}",
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),

                      const SizedBox(height: 15),
        
                      // Location section
                      Card(
                        elevation: 2,
                        color: backgroundGrey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withAlpha(30),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.location_on, color: Colors.blue, size: 30),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Локация", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                        Text(
                                          widget.campaign.location,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () => _openMap(widget.campaign.latitude, widget.campaign.longitude),
                                  icon: const Icon(Icons.map_outlined),
                                  label: const Text("Виж на картата"),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
        
                      const SizedBox(height: 20),
        
                      // Date section (start/end)
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoDateCard(
                              icon: Icons.calendar_today_outlined,
                              color: greenPrimary,
                              title: "Начало",
                              date: _formatDate(widget.campaign.startDate),
                              time: _formatTime(widget.campaign.startDate),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: _buildInfoDateCard(
                              icon: Icons.event_available_outlined,
                              color: Colors.orange,
                              title: "Край",
                              date: _formatDate(widget.campaign.endDate),
                              time: _formatTime(widget.campaign.endDate),
                            ),
                          ),
                        ],
                      ),
        
                      const SizedBox(height: 20),
        
                      // Volunteer progress card
                      _buildVolunteersCard(widget.campaign),
        
                      const SizedBox(height: 25),
        
                      // Description
                      const Text("За кампанията", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: backgroundGrey.withAlpha(100),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: blueSecondary.withAlpha(50)),
                        ),
                        child: Text(
                          widget.campaign.description,
                          style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
                        ),
                      ),
        
                      const SizedBox(height: 25),
        
                      // Instructions (if any)
                      if (widget.campaign.instructions.isNotEmpty) ...[
                        const Text("Инструкции", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha(15),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.orange.withAlpha(100)),
                          ),
                          child: Text(
                            widget.campaign.instructions,
                            style: TextStyle(fontSize: 15, height: 1.5, color: Colors.brown[900]),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Date (start/end) card widget
  Widget _buildInfoDateCard({
    required IconData icon,
    required Color color,
    required String title,
    required String date,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundGrey.withAlpha(100),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withAlpha(50), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [ 
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  // Registered volunteers card (progress bar)
  Widget _buildVolunteersCard(Campaign campaign) {
    int registered = campaign.registeredVolunteersUids.length;
    int required = campaign.requiredVolunteers;
    double progress = required > 0 ? (registered / required).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundGrey.withAlpha(100),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.withAlpha(50), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text("Доброволци", style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Записани: $registered", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text("Цел: $required", style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              color: progress >= 1.0 ? greenPrimary : Colors.blue,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  // Button at the bottom of the screen
  Widget _buildBottomButton(VolunteerUser user, bool isGuest) {
    bool isAlreadyRegistered = widget.campaign.registeredVolunteersUids.contains(user.uid);
    bool isEnded = widget.campaign.status == 'ended' || widget.campaign.endDate.isBefore(DateTime.now());
    bool isOrganizer = widget.campaign.organizerId == user.uid;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, -5),
            )
          ]
        ),
        child: SizedBox(
          height: 54.0,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: (isEnded || isOrganizer || isAlreadyRegistered)
                  ? Colors.grey.shade400 
                  : greenPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              elevation: 0,
            ),
            onPressed: (isEnded || isAlreadyRegistered || isOrganizer) ? null : () async {
              if (isGuest) {
                _showGuestActionMessage(context);
                return;
              }
              try {
                await DatabaseService(uid: user.uid).registerUserForCampaign(widget.campaign.id);

                if (!mounted) return;
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: greenPrimary,
                      content: Center(child: Text('Успешно се записахте за кампанията!', style: TextStyle(fontWeight: FontWeight.bold))),
                    ),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(backgroundColor: Colors.red, content: Center(child: Text('Грешка при записване!'))),
                  );
                }
              }
            },
            child: Text(
              isOrganizer
                ? 'Вие сте организаторът на кампанията!' 
                : (isEnded 
                  ? 'Тази кампания е приключила' 
                  : (isAlreadyRegistered 
                    ? 'Вече сте записан за кампанията' 
                    : 'Запиши се за кампанията')),
              style: TextStyle(fontSize: 16.0, color: (isEnded || isAlreadyRegistered || isOrganizer) ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}