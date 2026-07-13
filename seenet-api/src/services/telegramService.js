const axios = require('axios');

// Bot criado no @BotFather + GRUPO privado — definir no Railway:
//   TELEGRAM_BOT_TOKEN  (ex: 8123456:AAF...)
//   TELEGRAM_CHAT_ID    (id do grupo, ex: -1001234567890)
const TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const CHAT_ID = process.env.TELEGRAM_CHAT_ID;

function telegramConfigurado() {
  return !!(TOKEN && CHAT_ID);
}

/** Chamada genérica à API do Telegram (sendMessage, getUpdates, ...). */
async function apiTelegram(metodo, params = {}) {
  if (!TOKEN) return null;
  try {
    const resp = await axios.post(
      `https://api.telegram.org/bot${TOKEN}/${metodo}`,
      params,
      { timeout: 45000 } // > timeout do long-poll (30s)
    );
    return resp.data;
  } catch (error) {
    const desc = error.response?.data?.description || error.message;
    if (metodo !== 'getUpdates') console.error(`⚠️ Telegram ${metodo}:`, desc);
    return null;
  }
}

/** Envia mensagem pra um chat específico. */
async function enviarPara(chatId, texto, { parseMode = 'HTML' } = {}) {
  const d = await apiTelegram('sendMessage', {
    chat_id: chatId,
    text: texto,
    parse_mode: parseMode,
    disable_web_page_preview: true,
  });
  return d?.ok === true;
}

/** Envia pro chat padrão (TELEGRAM_CHAT_ID). No-op se não configurado. */
async function enviarTelegram(texto, opts) {
  if (!CHAT_ID) return false;
  return enviarPara(CHAT_ID, texto, opts);
}

module.exports = { telegramConfigurado, apiTelegram, enviarTelegram, enviarPara, CHAT_ID };
