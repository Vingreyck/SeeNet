// src/services/NotificationService.js
const admin = require('firebase-admin');

class NotificationService {
  constructor() {
    this._initialized = false;
    this._init();
  }

  _init() {
    try {
      const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
      if (!serviceAccountJson) {
        console.warn('⚠️ FIREBASE_SERVICE_ACCOUNT não configurada — push notifications desabilitadas');
        return;
      }

      const serviceAccount = JSON.parse(serviceAccountJson);

      if (!admin.apps.length) {
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
        });
      }

      this._initialized = true;
      console.log('✅ Firebase Admin SDK inicializado');
    } catch (error) {
      console.error('❌ Erro ao inicializar Firebase Admin:', error.message);
    }
  }

  async enviarPush(fcmToken, titulo, corpo, data = {}) {
    if (!this._initialized) {
      console.warn('⚠️ Firebase não inicializado — push não enviado');
      return false;
    }

    if (!fcmToken) {
      console.warn('⚠️ FCM token vazio — push não enviado');
      return false;
    }

    try {
      const message = {
        token: fcmToken,
        notification: { title: titulo, body: corpo },
        data: {
          ...Object.fromEntries(
            Object.entries(data).map(([k, v]) => [k, String(v)])
          ),
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'seenet_notifications',
            priority: 'high',
            defaultSound: true,
          },
        },
      };

      await admin.messaging().send(message);
      console.log(`✅ Push enviado: "${titulo}" → ${fcmToken.substring(0, 20)}...`);
      return true;
    } catch (error) {
      if (error.code === 'messaging/registration-token-not-registered' ||
          error.code === 'messaging/invalid-registration-token') {
        console.warn(`⚠️ FCM token inválido: ${fcmToken.substring(0, 20)}...`);
      } else {
        console.error('❌ Erro ao enviar push:', error.message);
      }
      return false;
    }
  }

  async enviarParaUsuario(db, usuarioId, titulo, corpo, data = {}) {
    try {
      const usuario = await db('usuarios')
        .where('id', usuarioId)
        .select('fcm_token', 'nome')
        .first();

      if (!usuario || !usuario.fcm_token) {
        console.warn(`⚠️ Usuário ${usuarioId} sem FCM token`);
        return false;
      }

      return await this.enviarPush(usuario.fcm_token, titulo, corpo, data);
    } catch (error) {
      console.error(`❌ Erro ao enviar para usuário ${usuarioId}:`, error.message);
      return false;
    }
  }

  /**
   * Envia push APENAS para gestores de segurança (NÃO inclui administradores)
   */
  async enviarParaGestores(db, tenantId, titulo, corpo, data = {}) {
    try {
      const gestores = await db('usuarios')
        .where('tenant_id', tenantId)
        .where('ativo', true)
        .where('tipo_usuario', 'gestor_seguranca')  // ✅ SÓ GESTOR DE SEGURANÇA
        .whereNotNull('fcm_token')
        .select('id', 'fcm_token', 'nome');

      let enviados = 0;
      for (const gestor of gestores) {
        const ok = await this.enviarPush(gestor.fcm_token, titulo, corpo, data);
        if (ok) enviados++;
      }

      console.log(`📤 Push enviado para ${enviados}/${gestores.length} gestores de segurança`);
      return enviados;
    } catch (error) {
      console.error('❌ Erro ao enviar para gestores:', error.message);
      return 0;
    }
  }
}

module.exports = new NotificationService();