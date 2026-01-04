importScripts('https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDa_6fZVuDgYLAb9m_ttkwsKKzdqPm67rc',
  appId: '1:554482574580:web:feafdbb45deabcfe53eaa1',
  messagingSenderId: '554482574580',
  projectId: 'smartbar-v3',
  authDomain: 'smartbar-v3.firebaseapp.com',
  storageBucket: 'smartbar-v3.firebasestorage.app',
  measurementId: 'G-NV798QZ7H5',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title || 'Smart Bar';
  const notificationOptions = {
    body: payload.notification?.body,
    icon: '/icons/Icon-192.png',
    data: payload.data,
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});
