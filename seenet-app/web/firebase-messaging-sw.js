// Service worker do Firebase Cloud Messaging — mostra notificações mesmo com
// a aba fechada/minimizada. O Firebase JS SDK registra esse arquivo sozinho
// (basta existir na raiz do site), não precisa de <script> extra no index.html.
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCEDz4kn7nM9QoSaeZJncxRoFXV00R6ubc',
  authDomain: 'seenet-3fdb2.firebaseapp.com',
  projectId: 'seenet-3fdb2',
  storageBucket: 'seenet-3fdb2.firebasestorage.app',
  messagingSenderId: '877316843670',
  appId: '1:877316843670:web:4926ee87656ca6d3cefab7',
});

const messaging = firebase.messaging();

// O payload "notification" (já enviado pelo backend hoje) já é exibido
// automaticamente pelo navegador — esse handler é só um log/fallback.
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Notificação em background:', payload);
});
