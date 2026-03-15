const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.notifyOnRegistration = functions.firestore
    .document("campaigns/{campaignId}")
    .onUpdate(async (change, context) => {
        const newValue = change.after.data();
        const previousValue = change.before.data();

        // Check if a new volunteer registered
        const newVolunteers = newValue.registeredVolunteersUids || [];
        const oldVolunteers = previousValue.registeredVolunteersUids || [];

        if (newVolunteers.length > oldVolunteers.length) {
            // A new ID was added
            const addedUid = newVolunteers.find((uid) => !oldVolunteers.includes(uid));

            if (!addedUid) return null;

            const organizerId = newValue.organizerId;
            // Don't notify if the organizer registered themselves somehow
            if (organizerId === addedUid) return null;

            // Fetch organizer details to get FCM token
            const organizerDoc = await admin.firestore().collection("volunteers").doc(organizerId).get();

            if (!organizerDoc.exists) {
                console.log("Organizer not found");
                return null;
            }

            const organizerData = organizerDoc.data();
            const fcmToken = organizerData.fcmToken;

            if (!fcmToken) {
                console.log("No FCM token found for organizer.");
                return null;
            }

            // Fetch volunteer details to include their name in the notification
            const volunteerDoc = await admin.firestore().collection("volunteers").doc(addedUid).get();
            let volunteerName = "A new volunteer";
            if (volunteerDoc.exists) {
                const volData = volunteerDoc.data();
                volunteerName = `${volData.firstName} ${volData.lastName}`;
            }

            const message = {
                notification: {
                    title: "Нов доброволец!",
                    body: `${volunteerName} се записа за вашата кампания: ${newValue.title}`,
                },
                data: {
                    campaignId: context.params.campaignId,
                    type: "registration",
                },
                token: fcmToken
            };

            try {
                const response = await admin.messaging().send(message);
                console.log("Notification sent successfully:", response);
            } catch (error) {
                console.error("Error sending notification:", error);
            }
        }
        return null;
    });
