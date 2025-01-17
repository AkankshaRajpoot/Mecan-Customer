importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js");

firebase.initializeApp({
  apiKey: "AIzaSyBa7rtEddUrKnvDV0ekNa6RkWOozvB2yoc",
    authDomain: "mecan-db9f9.firebaseapp.com",
    projectId: "mecan-db9f9",
    storageBucket: "mecan-db9f9.appspot.com",
    messagingSenderId: "41720817871",
    appId: "1:41720817871:web:e376f44b9e6853ed85afba",
    measurementId: "G-KDEJ4P89TT"
});

const messaging = firebase.messaging();

messaging.setBackgroundMessageHandler(function (payload) {
    const promiseChain = clients
        .matchAll({
            type: "window",
            includeUncontrolled: true
        })
        .then(windowClients => {
            for (let i = 0; i < windowClients.length; i++) {
                const windowClient = windowClients[i];
                windowClient.postMessage(payload);
            }
        })
        .then(() => {
            const title = payload.notification.title;
            const options = {
                body: payload.notification.score
              };
            return registration.showNotification(title, options);
        });
    return promiseChain;
});
self.addEventListener('notificationclick', function (event) {
    console.log('notification received: ', event)
});