import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../models/usuario.dart';

class UsuarioTable {
  static const String tableName = 'usuarios';
  
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        senha TEXT NOT NULL,
        tipo_usuario TEXT NOT NULL CHECK (tipo_usuario IN ('tecnico', 'administrador')),
        ativo INTEGER DEFAULT 1,
        data_criacao TEXT DEFAULT CURRENT_TIMESTAMP,
        data_atualizacao TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }
  
  static Future<void> insertInitialData(Database db) async {
    await db.insert(tableName, {
      'nome': 'Administrador',
      'email': 'admin@seenet.com',
      'senha': _hashPassword('admin123'),
      'tipo_usuario': 'administrador',
    });
    
    await db.insert(tableName, {
      'nome': 'Técnico Teste',
      'email': 'tecnico@seenet.com',
      'senha': _hashPassword('123456'),
      'tipo_usuario': 'tecnico',
    });
  }
  
  static Future<Usuario?> login(Database db, String email, String senha) async {
    try {
      String senhaHash = _hashPassword(senha);
      
      List<Map<String, dynamic>> results = await db.query(
        tableName,
        where: 'email = ? AND (senha = ? OR senha = ?) AND ativo = 1',
        whereArgs: [email, senha, senhaHash],
      );
      
      if (results.isNotEmpty) {
        print('✅ Login: $email');
        return Usuario.fromMap(results.first);
      }
      return null;
    } catch (e) {
      print('❌ Erro login: $e');
      return null;
    }
  }
  
  static Future<bool> insert(Database db, Usuario usuario) async {
    try {
      await db.insert(tableName, {
        'nome': usuario.nome,
        'email': usuario.email,
        'senha': _hashPassword(usuario.senha),
        'tipo_usuario': usuario.tipoUsuario,
        'ativo': usuario.ativo ? 1 : 0,
      });
      return true;
    } catch (e) {
      print('❌ Erro criar usuário: $e');
      return false;
    }
  }
  
  static String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
}