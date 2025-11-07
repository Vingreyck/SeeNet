const express = require('express');
const { google } = require('googleapis');
const router = express.Router();

// Configurar Play Integrity API
const playintegrity = google.playintegrity({
  version: 'v1',
  auth: new google.auth.GoogleAuth({
    credentials: process.env.GOOGLE_SERVICE_ACCOUNT_JSON 
      ? JSON.parse(process.env.GOOGLE_SERVICE_ACCOUNT_JSON)
      : require('../service-account.json'),
    scopes: ['https://www.googleapis.com/auth/playintegrity'],
  }),
});

router.post('/verify-integrity', async (req, res) => {
  const { integrityToken } = req.body;
  
  if (!integrityToken) {
    return res.status(400).json({
      isValid: false,
      error: 'Token não fornecido',
    });
  }
  
  try {
    // Descriptografar e validar token com Google Play
    const response = await playintegrity.v1.decodeIntegrityToken({
      packageName: 'com.seenet.app',
      requestBody: {
        integrityToken: integrityToken,
      },
    });
    
    const verdict = response.data.tokenPayloadExternal;
    
    // Extrair vereditos
    const deviceIntegrity = verdict.deviceIntegrity?.deviceRecognitionVerdict || [];
    const appIntegrity = verdict.appIntegrity?.appRecognitionVerdict;
    const accountDetails = verdict.accountDetails?.appLicensingVerdict;
    
    // Validar integridade
    const hasDeviceIntegrity = 
      deviceIntegrity.includes('MEETS_DEVICE_INTEGRITY') ||
      deviceIntegrity.includes('MEETS_BASIC_INTEGRITY');
    
    const hasAppIntegrity = appIntegrity === 'PLAY_RECOGNIZED';
    
    const isLicensed = accountDetails === 'LICENSED';
    
    const isValid = hasDeviceIntegrity && hasAppIntegrity;
    
    res.json({
      isValid,
      deviceIntegrity: hasDeviceIntegrity,
      appIntegrity: hasAppIntegrity,
      isLicensed,
      verdict: {
        device: deviceIntegrity,
        app: appIntegrity,
        license: accountDetails,
      },
    });
    
  } catch (error) {
    console.error('Erro ao validar integridade:', error);
    res.status(500).json({
      isValid: false,
      error: 'Erro ao processar token',
      details: error.message,
    });
  }
});

module.exports = router;