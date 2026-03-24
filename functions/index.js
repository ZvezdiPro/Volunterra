const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { calculateDistanceInKm } = require("./utils/geo");
admin.initializeApp();
exports.notifyOnRegistration = functions.firestore
    .document("campaigns/{campaignId}")
    .onUpdate(async (change, context) => {
        const newValue = change.after.data();
        const previousValue = change.before.data();

        // Check if a new volunteer registered
        const newVolunteers = newValue.registeredVolunteersUids || [];
        const oldVolunteers = previousValue.registeredVolunteersUids || [];

        // If the organizer changed, an ownership transfer is taking place.
        if (newValue.organizerId !== previousValue.organizerId) {
            console.log("Ownership transfer detected in notifyOnRegistration. Skipping registration alert.");
            return null;
        }

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

            // Check if the required number of volunteers has been reached
            if (newValue.requiredVolunteers > 0 && newVolunteers.length === newValue.requiredVolunteers) {
                const goalMessage = {
                    notification: {
                        title: "Целта е постигната!",
                        body: `Кампанията "${newValue.title}" събра необходимите ${newValue.requiredVolunteers} доброволци!`,
                    },
                    data: {
                        campaignId: context.params.campaignId,
                        type: "goal_reached",
                    },
                    token: fcmToken
                };

                try {
                    const goalResponse = await admin.messaging().send(goalMessage);
                    console.log("Goal reached notification sent successfully:", goalResponse);
                } catch (error) {
                    console.error("Error sending goal reached notification:", error);
                }
            }
        }
        return null;
    });

exports.notifyOnCampaignUpdate = functions.firestore
    .document("campaigns/{campaignId}")
    .onUpdate(async (change, context) => {
        const newValue = change.after.data();
        const previousValue = change.before.data();

        // Safe conversion of Timestamps to milliseconds for comparison, if they exist
        const newStartMillis = newValue.startDate ? newValue.startDate.toMillis() : null;
        const oldStartMillis = previousValue.startDate ? previousValue.startDate.toMillis() : null;
        
        const newEndMillis = newValue.endDate ? newValue.endDate.toMillis() : null;
        const oldEndMillis = previousValue.endDate ? previousValue.endDate.toMillis() : null;

        // Check if any significant fields changed
        const startChanged = newStartMillis !== oldStartMillis;
        const endChanged = newEndMillis !== oldEndMillis;
        const locationChanged = newValue.location !== previousValue.location;
        const instructionsChanged = newValue.instructions !== previousValue.instructions;
        const organizerChanged = newValue.organizerId !== previousValue.organizerId;
        
        const newCoorgs = newValue.coorganizersIds || [];
        const oldCoorgs = previousValue.coorganizersIds || [];
        const coorgAdded = newCoorgs.length > oldCoorgs.length;

        if (!startChanged && !endChanged && !locationChanged && !instructionsChanged && !organizerChanged && !coorgAdded) {
            return null; // Return early if none of the target fields changed 
        }

        // Handle ownership transfer (notify new organizer)
        if (organizerChanged) {
            const newOrganizerDoc = await admin.firestore().collection("volunteers").doc(newValue.organizerId).get();
            if (newOrganizerDoc.exists) {
                const newOrgData = newOrganizerDoc.data();
                if (newOrgData.fcmToken) {
                    const transferMessage = {
                        notification: {
                            title: "Нов статус!",
                            body: `Честито! Вече сте организатор на кампания "${newValue.title}"!`,
                        },
                        data: {
                            campaignId: context.params.campaignId,
                            type: "ownership_transfer",
                        },
                        token: newOrgData.fcmToken
                    };
                    try {
                        await admin.messaging().send(transferMessage);
                        console.log("Ownership transfer notification sent successfully to UID:", newValue.organizerId);
                    } catch (error) {
                        console.error("Error sending ownership transfer notification:", error);
                    }
                }
            }
        }

        // Handle co-organizer added (notify new co-organizer)
        if (coorgAdded) {
            const addedUid = newCoorgs.find(uid => !oldCoorgs.includes(uid));
            if (addedUid) {
                const newCoorgDoc = await admin.firestore().collection("volunteers").doc(addedUid).get();
                if (newCoorgDoc.exists) {
                    const newCoorgData = newCoorgDoc.data();
                    if (newCoorgData.fcmToken) {
                        const coorgMessage = {
                            notification: {
                                title: "Нови права в кампания!",
                                body: `Вече сте съорганизатор на кампания "${newValue.title}"!`,
                            },
                            data: {
                                campaignId: context.params.campaignId,
                                type: "coorganizer_added",
                            },
                            token: newCoorgData.fcmToken
                        };
                        try {
                            await admin.messaging().send(coorgMessage);
                            console.log("Co-organizer notification sent successfully to UID:", addedUid);
                        } catch (error) {
                            console.error("Error sending co-organizer notification:", error);
                        }
                    }
                }
            }
        }

        // Only continue to volunteer notifications if one of the specific info fields changed
        if (!startChanged && !endChanged && !locationChanged && !instructionsChanged) {
            return null;
        }

        const registeredVolunteers = newValue.registeredVolunteersUids || [];
        
        if (registeredVolunteers.length === 0) {
            return null;
        }

        // Fetch tokens for all registered volunteers
        const tokens = [];
        
        try {
            // Firestore 'in' query supports up to 30 elements, chunk it just in case
            const chunks = [];
            for (let i = 0; i < registeredVolunteers.length; i += 30) {
                chunks.push(registeredVolunteers.slice(i, i + 30));
            }

            for (const chunk of chunks) {
                const volunteersSnapshot = await admin.firestore()
                    .collection("volunteers")
                    .where(admin.firestore.FieldPath.documentId(), "in", chunk)
                    .get();

                volunteersSnapshot.forEach((doc) => {
                    const data = doc.data();
                    if (data.fcmToken) {
                        tokens.push(data.fcmToken);
                    }
                });
            }
        } catch (error) {
            console.error("Error fetching volunteer tokens:", error);
            return null;
        }

        if (tokens.length === 0) {
            console.log("No FCM tokens found for registered volunteers.");
            return null;
        }

        let changeDetailText = "";
        if (startChanged) changeDetailText += "началото, ";
        if (endChanged) changeDetailText += "края, ";
        if (locationChanged) changeDetailText += "мястото, ";
        if (instructionsChanged) changeDetailText += "инструкциите, ";

        // Remove the trailing comma and space
        changeDetailText = changeDetailText.slice(0, -2);
        
        const lastCommaIndex = changeDetailText.lastIndexOf(", ");
        if (lastCommaIndex !== -1) {
            changeDetailText = changeDetailText.substring(0, lastCommaIndex) + " и " + changeDetailText.substring(lastCommaIndex + 2);
        }

        const baseMessage = {
            notification: {
                title: "Промяна в кампания!",
                body: `Организаторът промени ${changeDetailText} на кампания "${newValue.title}".`,
            },
            data: {
                campaignId: context.params.campaignId,
                type: "campaign_update",
            }
        };

        const promises = tokens.map(token => {
            const message = {
                ...baseMessage,
                token: token
            };
            return admin.messaging().send(message);
        });

        try {
            const responses = await Promise.allSettled(promises);
            let successCount = 0;
            let failureCount = 0;
            const failedTokens = [];

            responses.forEach((resp, idx) => {
                if (resp.status === 'fulfilled') {
                    successCount++;
                } else {
                    failureCount++;
                    failedTokens.push(tokens[idx]);
                    console.error("Error sending to token:", tokens[idx], resp.reason);
                }
            });

            console.log(`${successCount} messages were sent successfully.`);
            if (failureCount > 0) {
                console.log(`Failed to send to ${failureCount} tokens:`, failedTokens);
            }
        } catch (error) {
            console.error("Fatal error sending update notifications:", error);
        }

        return null;
    });

exports.notifyOnChatMessage = functions.firestore
    .document("campaigns/{campaignId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
        const messageData = snap.data();
        const campaignId = context.params.campaignId;
        
        const senderId = messageData.senderId;
        const senderName = messageData.senderName || "Доброволец";
        const type = messageData.type || "text";
        let messageText = messageData.text || "";

        if (messageText.trim() === "") {
            if (type === "image") messageText = "📷 Снимка";
            else if (type === "audio") messageText = "🎤 Гласово съобщение";
            else if (type === "video") messageText = "🎥 Видео";
            else if (type === "file") {
                messageText = messageData.fileName ? `📄 Файл: ${messageData.fileName}` : "📄 Файл";
            }
            else if (type === "contact") {
                messageText = messageData.contactName ? `👤 Контакт: ${messageData.contactName}` : "👤 Контакт";
            }
            else messageText = "Медия";
        } else if (type === "contact") {
            messageText = messageData.contactName ? `👤 Контакт: ${messageData.contactName}` : "👤 Контакт";
        }

        // Fetch campaign details
        const campaignDoc = await admin.firestore().collection("campaigns").doc(campaignId).get();
        if (!campaignDoc.exists) return null;

        const campaignData = campaignDoc.data();
        const campaignTitle = campaignData.title || "Кампания";
        const organizerId = campaignData.organizerId;
        const registeredVolunteers = campaignData.registeredVolunteersUids || [];

        // Combine all participants
        let participants = new Set([...registeredVolunteers]);
        if (organizerId) participants.add(organizerId);

        // Remove the sender from the receivers list
        participants.delete(senderId);

        if (participants.size === 0) return null;

        const receiversArray = Array.from(participants);
        const tokens = [];

        try {
            // Fetch tokens in chunks of 30
            const chunks = [];
            for (let i = 0; i < receiversArray.length; i += 30) {
                chunks.push(receiversArray.slice(i, i + 30));
            }

            for (const chunk of chunks) {
                const snapshot = await admin.firestore()
                    .collection("volunteers")
                    .where(admin.firestore.FieldPath.documentId(), "in", chunk)
                    .get();

                snapshot.forEach((doc) => {
                    const data = doc.data();
                    if (data.fcmToken) {
                        tokens.push(data.fcmToken);
                    }
                });
            }
        } catch (error) {
            console.error("Error fetching tokens for chat message:", error);
            return null;
        }

        if (tokens.length === 0) return null;

        // Truncate message text if too long
        if (messageText && messageText.length > 100) {
            messageText = messageText.substring(0, 97) + "...";
        }

        const baseMessage = {
            notification: {
                title: `${campaignTitle} - ново съобщение`,
                body: `${senderName}: ${messageText}`,
            },
            data: {
                campaignId: campaignId,
                type: "chat_message",
            }
        };

        const promises = tokens.map(token => {
            const pushMessage = {
                ...baseMessage,
                token: token
            };
            return admin.messaging().send(pushMessage);
        });

        try {
            const responses = await Promise.allSettled(promises);
            let successCount = 0;
            let failureCount = 0;

            responses.forEach((resp) => {
                if (resp.status === 'fulfilled') {
                    successCount++;
                } else {
                    failureCount++;
                }
            });

            console.log(`Chat message: ${successCount} notifications sent successfully, ${failureCount} failed.`);
        } catch (error) {
            console.error("Fatal error sending chat notifications:", error);
        }

        return null;
    });

exports.scheduledStartNotification = functions.pubsub.schedule("every 15 minutes").onRun(async (context) => {
    const now = new Date();
    const twoHoursAndFifteenFromNow = new Date(now.getTime() + (2 * 60 + 15) * 60 * 1000);
    
    // Explicitly using Firestore Timestamps for query bounds
    const nowTimestamp = admin.firestore.Timestamp.fromDate(now);
    const futureTimestamp = admin.firestore.Timestamp.fromDate(twoHoursAndFifteenFromNow);

    console.log(`Running scheduled check. Now: ${now.toISOString()}, Future: ${twoHoursAndFifteenFromNow.toISOString()}`);

    const snapshot = await admin.firestore().collection("campaigns")
        .where("status", "==", "active")
        .where("startDate", "<=", futureTimestamp)
        .where("startDate", ">=", nowTimestamp)
        .get();

    if (snapshot.empty) {
        console.log("No campaigns found starting in the 2h 15m window.");
        const anyActive = await admin.firestore().collection("campaigns").where("status", "==", "active").limit(5).get();
        anyActive.forEach(doc => {
            const d = doc.data();
            console.log(`Active campaign found: "${d.title}", startDate: ${d.startDate ? d.startDate.toDate().toISOString() : 'N/A'}, startNotificationSent: ${d.startNotificationSent}`);
        });
        return null;
    }

    const campaignsToNotify = [];
    snapshot.forEach(doc => {
        const data = doc.data();
        if (!data.startNotificationSent) {
            campaignsToNotify.push({ id: doc.id, ...data });
        } else {
            console.log(`Campaign "${data.title}" (${doc.id}) skipped because startNotificationSent is already true.`);
        }
    });

    if (campaignsToNotify.length === 0) {
        console.log("Found matching campaigns, but all were already notified.");
        return null;
    }

    for (const campaign of campaignsToNotify) {
        const campaignId = campaign.id;
        const organizerId = campaign.organizerId;
        const registeredVolunteers = campaign.registeredVolunteersUids || [];
        const campaignTitle = campaign.title || "Кампания";

        console.log(`Processing notification for "${campaignTitle}" (${campaignId}). Participants count: ${registeredVolunteers.length + (organizerId ? 1 : 0)}`);

        // Mark as sent immediately
        await admin.firestore().collection("campaigns").doc(campaignId).update({
            startNotificationSent: true
        });

        let participants = new Set([...registeredVolunteers]);
        if (organizerId) participants.add(organizerId);

        if (participants.size === 0) {
            console.log(`No participants to notify for ${campaignTitle}`);
            continue;
        }

        const receiversArray = Array.from(participants);
        const tokens = [];

        try {
            const chunks = [];
            for (let i = 0; i < receiversArray.length; i += 30) {
                chunks.push(receiversArray.slice(i, i + 30));
            }

            for (const chunk of chunks) {
                const volSnapshot = await admin.firestore()
                    .collection("volunteers")
                    .where(admin.firestore.FieldPath.documentId(), "in", chunk)
                    .get();

                volSnapshot.forEach((doc) => {
                    const data = doc.data();
                    if (data.fcmToken) {
                        tokens.push(data.fcmToken);
                    } else {
                        console.log(`Volunteer ${doc.id} has no FCM token.`);
                    }
                });
            }
        } catch (error) {
            console.error(`Error fetching tokens for campaign ${campaignId}:`, error);
            continue;
        }

        if (tokens.length === 0) {
            console.log(`No FCM tokens found for any participants of ${campaignTitle}.`);
            continue;
        }

        const baseMessage = {
            notification: {
                title: "Кампанията започва скоро!",
                body: `Кампанията "${campaignTitle}" започва след около 2 часа. Приготви се!`,
            },
            data: {
                campaignId: campaignId,
                type: "campaign_starting_soon",
            }
        };

        const promises = tokens.map(token => {
            const pushMessage = { ...baseMessage, token: token };
            return admin.messaging().send(pushMessage);
        });

        const responses = await Promise.allSettled(promises);
        const successCount = responses.filter(r => r.status === 'fulfilled').length;
        console.log(`Scheduled reminder for "${campaignTitle}": ${successCount}/${tokens.length} notifications sent.`);
    }

    return null;
});

exports.notifyOnNewCampaign = functions.firestore
    .document("campaigns/{campaignId}")
    .onCreate(async (snap, context) => {
        const campaignData = snap.data();
        
        // Ensure campaign is active
        if (campaignData.status !== "active") return null;

        const campaignId = context.params.campaignId;
        const campaignTitle = campaignData.title || "Нова кампания";
        const organizerId = campaignData.organizerId;
        const categories = campaignData.categories || [];
        const campaignLat = campaignData.latitude;
        const campaignLng = campaignData.longitude;

        // Fetch all volunteers        
        let validCategories = categories;
        if (validCategories.length > 10) validCategories = validCategories.slice(0, 10);

        let volunteersQuery;
        try {
            volunteersQuery = await admin.firestore().collection("volunteers")
                .where("interests", "array-contains-any", validCategories)
                .get();
        } catch (error) {
            console.error("Error querying volunteers for new campaign:", error);
            // We shouldn't return here if we want to still notify followers, but the query failed
            // Let's just set volunteersQuery = null
            volunteersQuery = null;
        }

        const tokensSet = new Set();

        if (volunteersQuery && !volunteersQuery.empty) {
            volunteersQuery.forEach(doc => {
                const volunteerId = doc.id;
                const data = doc.data();

                // Don't notify the organizer about their own campaign
                if (volunteerId === organizerId) return;

                // They must have a token
                if (!data.fcmToken) return;

                // They must have a location
                if (!data.lastKnownLatitude || !data.lastKnownLongitude) return;

                // Calculate distance
                const distance = calculateDistanceInKm(
                    campaignLat, campaignLng,
                    data.lastKnownLatitude, data.lastKnownLongitude
                );

                // Within 20km radius
                if (distance <= 20) {
                    tokensSet.add(data.fcmToken);
                }
            });
        }

        // Add NGO Followers and Members
        try {
            const ngoDoc = await admin.firestore().collection("ngos").doc(organizerId).get();
            if (ngoDoc.exists) {
                const ngoData = ngoDoc.data();
                const followers = ngoData.followers || [];
                const members = ngoData.members || [];
                const ngoAffiliates = [...new Set([...followers, ...members])];
                
                if (ngoAffiliates.length > 0) {
                    const chunks = [];
                    for (let i = 0; i < ngoAffiliates.length; i += 30) {
                        chunks.push(ngoAffiliates.slice(i, i + 30));
                    }

                    for (const chunk of chunks) {
                        const snap = await admin.firestore()
                            .collection("volunteers")
                            .where(admin.firestore.FieldPath.documentId(), "in", chunk)
                            .get();

                        snap.forEach(doc => {
                            const data = doc.data();
                            if (data.fcmToken && doc.id !== organizerId) {
                                tokensSet.add(data.fcmToken);
                            }
                        });
                    }
                }
            }
        } catch (error) {
            console.error("Error fetching NGO affiliates for new campaign:", error);
        }

        const uniqueTokens = Array.from(tokensSet);

        if (uniqueTokens.length === 0) {
            console.log(`No users to notify for new campaign ${campaignId}`);
            return null;
        }

        const baseMessage = {
            notification: {
                title: "Нова кампания!",
                body: `Кампанията "${campaignTitle}" търси доброволци!`,
            },
            data: {
                campaignId: campaignId,
                type: "new_campaign",
            }
        };

        const promises = uniqueTokens.map(token => {
            const pushMessage = { ...baseMessage, token: token };
            return admin.messaging().send(pushMessage);
        });

        const responses = await Promise.allSettled(promises);
        const successCount = responses.filter(r => r.status === 'fulfilled').length;
        console.log(`New campaign notification "${campaignTitle}" sent to ${successCount}/${uniqueTokens.length} users.`);

        return null;
    });

exports.notifyNgoOnNewFollower = functions.firestore
    .document("ngos/{ngoId}")
    .onUpdate(async (change, context) => {
        const newValue = change.after.data();
        const previousValue = change.before.data();
        
        const newFollowers = newValue.followers || [];
        const oldFollowers = previousValue.followers || [];
        
        // Check if an element was added
        if (newFollowers.length > oldFollowers.length) {
            const addedUid = newFollowers.find(id => !oldFollowers.includes(id));
            if (!addedUid) return null;
            
            const fcmToken = newValue.fcmToken;
            if (!fcmToken) return null;
            
            // Get volunteer's name
            const volunteerDoc = await admin.firestore().collection("volunteers").doc(addedUid).get();
            let volunteerName = "Нов потребител";
            if (volunteerDoc.exists) {
                const volData = volunteerDoc.data();
                volunteerName = `${volData.firstName} ${volData.lastName}`;
            }
            
            const message = {
                notification: {
                    title: "Нов последовател!",
                    body: `${volunteerName} вече ви следва.`,
                },
                data: {
                    ngoId: context.params.ngoId,
                    type: "new_follower",
                },
                token: fcmToken
            };
            
            try {
                await admin.messaging().send(message);
                console.log("New follower notification sent successfully to NGO:", context.params.ngoId);
            } catch (error) {
                console.error("Error sending new follower notification:", error);
            }
        }
        return null;
    });

exports.notifyOnNgoChatMessage = functions.firestore
    .document("ngos/{ngoId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
        const messageData = snap.data();
        const ngoId = context.params.ngoId;
        
        const senderId = messageData.senderId;
        const senderName = messageData.senderName || "Организация";
        const type = messageData.type || "text";
        let messageText = messageData.text || "";

        if (messageText.trim() === "") {
            if (type === "image") messageText = "📷 Снимка";
            else if (type === "audio") messageText = "🎤 Гласово съобщение";
            else if (type === "video") messageText = "🎥 Видео";
            else if (type === "file") {
                messageText = messageData.fileName ? `📄 Файл: ${messageData.fileName}` : "📄 Файл";
            }
            else if (type === "contact") {
                messageText = messageData.contactName ? `👤 Контакт: ${messageData.contactName}` : "👤 Контакт";
            }
            else messageText = "Медия";
        } else if (type === "contact") {
            messageText = messageData.contactName ? `👤 Контакт: ${messageData.contactName}` : "👤 Контакт";
        }

        // Fetch NGO details
        const ngoDoc = await admin.firestore().collection("ngos").doc(ngoId).get();
        if (!ngoDoc.exists) return null;

        const ngoData = ngoDoc.data();
        const ngoTitle = ngoData.name || "Организация";
        const members = ngoData.members || [];
        const admins = ngoData.admins || [];

        // Combine all participants
        let participants = new Set([...members, ...admins]);

        // Remove the sender from the receivers list
        if (senderId) {
            participants.delete(senderId);
        }

        if (participants.size === 0) return null;

        const receiversArray = Array.from(participants);
        const tokens = [];

        try {
            // Fetch tokens in chunks of 30
            const chunks = [];
            for (let i = 0; i < receiversArray.length; i += 30) {
                chunks.push(receiversArray.slice(i, i + 30));
            }

            for (const chunk of chunks) {
                const snapshot = await admin.firestore()
                    .collection("volunteers")
                    .where(admin.firestore.FieldPath.documentId(), "in", chunk)
                    .get();

                snapshot.forEach((doc) => {
                    const data = doc.data();
                    if (data.fcmToken) {
                        tokens.push(data.fcmToken);
                    }
                });
            }
        } catch (error) {
            console.error("Error fetching tokens for NGO chat message:", error);
            return null;
        }

        if (tokens.length === 0) return null;

        // Truncate message text if too long
        if (messageText && messageText.length > 100) {
            messageText = messageText.substring(0, 97) + "...";
        }

        const baseMessage = {
            notification: {
                title: `${ngoTitle} - инфо канал`,
                body: `${senderName}: ${messageText}`,
            },
            data: {
                ngoId: ngoId,
                type: "ngo_chat_message",
            }
        };

        const promises = tokens.map(token => {
            const pushMessage = {
                ...baseMessage,
                token: token
            };
            return admin.messaging().send(pushMessage);
        });

        try {
            const responses = await Promise.allSettled(promises);
            let successCount = 0;
            let failureCount = 0;

            responses.forEach((resp) => {
                if (resp.status === 'fulfilled') {
                    successCount++;
                } else {
                    failureCount++;
                }
            });

            console.log(`NGO chat message: ${successCount} notifications sent successfully, ${failureCount} failed.`);
        } catch (error) {
            console.error("Fatal error sending NGO chat notifications:", error);
        }

        return null;
    });

exports.notifyOnCampaignEnded = functions.firestore
    .document("campaigns/{campaignId}")
    .onUpdate(async (change, context) => {
        const newValue = change.after.data();
        const previousValue = change.before.data();

        // Only fire when status changes to 'ended'
        if (previousValue.status === "ended" || newValue.status !== "ended") {
            return null;
        }

        const campaignTitle = newValue.title || "Кампания";
        const registeredVolunteers = newValue.registeredVolunteersUids || [];

        if (registeredVolunteers.length === 0) {
            console.log(`No volunteers to notify for ended campaign: ${campaignTitle}`);
            return null;
        }

        // Fetch FCM tokens for all registered volunteers in chunks of 30
        const tokens = [];
        try {
            const chunks = [];
            for (let i = 0; i < registeredVolunteers.length; i += 30) {
                chunks.push(registeredVolunteers.slice(i, i + 30));
            }

            for (const chunk of chunks) {
                const snapshot = await admin.firestore()
                    .collection("volunteers")
                    .where(admin.firestore.FieldPath.documentId(), "in", chunk)
                    .get();

                snapshot.forEach((doc) => {
                    const data = doc.data();
                    if (data.fcmToken) {
                        tokens.push(data.fcmToken);
                    }
                });
            }
        } catch (error) {
            console.error("Error fetching volunteer tokens for ended campaign:", error);
            return null;
        }

        if (tokens.length === 0) {
            console.log("No FCM tokens found for registered volunteers.");
            return null;
        }

        const baseMessage = {
            notification: {
                title: "Кампанията е прекратена",
                body: `Организаторът прекрати кампания "${campaignTitle}".`,
            },
            data: {
                campaignId: context.params.campaignId,
                type: "campaign_ended",
            },
        };

        const promises = tokens.map(token => {
            const message = { ...baseMessage, token: token };
            return admin.messaging().send(message);
        });

        try {
            const responses = await Promise.allSettled(promises);
            const successCount = responses.filter(r => r.status === "fulfilled").length;
            const failureCount = responses.length - successCount;
            console.log(`Campaign ended "${campaignTitle}": ${successCount} notifications sent, ${failureCount} failed.`);
        } catch (error) {
            console.error("Fatal error sending campaign ended notifications:", error);
        }

        return null;
    });
