package com.seenet.app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import com.google.android.gms.tasks.Task

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.seenet.app/integrity"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestIntegrityToken" -> {
                    val nonce = call.argument<String>("nonce")
                    val cloudProjectNumber = call.argument<Long>("cloudProjectNumber")
                    
                    if (nonce == null || cloudProjectNumber == null) {
                        result.error("INVALID_PARAMS", "Nonce or cloudProjectNumber missing", null)
                        return@setMethodCallHandler
                    }
                    
                    requestIntegrityToken(nonce, cloudProjectNumber, result)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun requestIntegrityToken(nonce: String, cloudProjectNumber: Long, result: MethodChannel.Result) {
        val integrityManager = IntegrityManagerFactory.create(applicationContext)
        
        val integrityTokenRequest = IntegrityTokenRequest.builder()
            .setNonce(nonce)
            .setCloudProjectNumber(cloudProjectNumber)
            .build()
        
        integrityManager.requestIntegrityToken(integrityTokenRequest)
            .addOnSuccessListener { response ->
                val token = response.token()
                result.success(token)
            }
            .addOnFailureListener { exception ->
                result.error("INTEGRITY_ERROR", exception.message, null)
            }
    }
}