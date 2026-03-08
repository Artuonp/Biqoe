const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendNewReservationNotification = functions.firestore
    .document("reservaciones/{userId}/reservas/{reservaId}")
    .onCreate((snap, context) => {
      const newValue = snap.data();
      const supplierId = newValue.supplier;

      // Obtener el token de FCM del proveedor
      return admin.firestore().collection("users").doc(supplierId).get()
          .then((userDoc) => {
            const fcmToken = userDoc.data().fcmToken;

            const payload = {
              notification: {
                title: "Nueva Reserva",
                body: `Tienes una nueva reserva para el plan ${
                  newValue.planID}`,
              },
              token: fcmToken,
            };

            return admin.messaging().send(payload).then((response) => {
              console.log("Successfully sent message:", response);
            }).catch((error) => {
              console.log("Error sending message:", error);
            });
          });
    });

// Nueva función para obtener usuario por slug
exports.getUserBySlug = functions.https.onCall(async (data, context) => {
  const slug = data.slug;
  if (!slug) {
    throw new functions.https.HttpsError("invalid-argument", "Se requiere slug");
  }
  const snapshot = await admin.firestore()
      .collection("usuarios")
      .where("slug", "==", slug)
      .limit(1)
      .get();
  if (snapshot.empty) {
    return null;
  }
  const doc = snapshot.docs[0];
  return { id: doc.id, ...doc.data() };
});
