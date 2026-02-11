// lib/ordem_de_servico/screens/apr_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/api_service.dart';
import '../../models/ordem_servico_model.dart';

// ──────────────────────────────────────────────
// MODELOS LOCAIS
// ──────────────────────────────────────────────

class CategoriaApr {
  final int id;
  final String nome;
  final int ordem;
  final List<PerguntaApr> perguntas;

  CategoriaApr({required this.id, required this.nome, required this.ordem, required this.perguntas});

  factory CategoriaApr.fromJson(Map<String, dynamic> json) => CategoriaApr(
    id: json['id'],
    nome: json['nome'],
    ordem: json['ordem'],
    perguntas: (json['perguntas'] as List).map((p) => PerguntaApr.fromJson(p)).toList(),
  );
}

class PerguntaApr {
  final int id;
  final int categoriaId;
  final String pergunta;
  final String tipoResposta; // 'sim_nao' | 'multipla_escolha' | 'texto'
  final bool obrigatorio;
  final String? requerJustificativaSe; // 'sim' | 'nao' | null
  final List<OpcaoApr> opcoes;

  PerguntaApr({
    required this.id, required this.categoriaId, required this.pergunta,
    required this.tipoResposta, required this.obrigatorio,
    this.requerJustificativaSe, required this.opcoes,
  });

  factory PerguntaApr.fromJson(Map<String, dynamic> json) => PerguntaApr(
    id: json['id'],
    categoriaId: json['categoria_id'],
    pergunta: json['pergunta'],
    tipoResposta: json['tipo_resposta'],
    obrigatorio: json['obrigatorio'] ?? true,
    requerJustificativaSe: json['requer_justificativa_se'],
    opcoes: ((json['opcoes'] ?? []) as List).map((o) => OpcaoApr.fromJson(o)).toList(),
  );
}

class OpcaoApr {
  final int id;
  final String opcao;
  final int ordem;

  OpcaoApr({required this.id, required this.opcao, required this.ordem});

  factory OpcaoApr.fromJson(Map<String, dynamic> json) =>
      OpcaoApr(id: json['id'], opcao: json['opcao'], ordem: json['ordem']);
}

// ──────────────────────────────────────────────
// TELA APR
// ──────────────────────────────────────────────

class AprScreen extends StatefulWidget {
  final OrdemServico os;
  const AprScreen({super.key, required this.os});

  @override
  State<AprScreen> createState() => _AprScreenState();
}

class _AprScreenState extends State<AprScreen> {
  final ApiService _api = ApiService.instance;
  late OrdemServico os;

  bool _carregando = true;
  bool _salvando = false;
  String? _erro;
  List<CategoriaApr> _categorias = [];

  final Map<int, String> _respostasSN = {};
  final Map<int, TextEditingController> _justificativas = {};
  final Map<int, TextEditingController> _respostasTexto = {};
  final Set<int> _episSelecionados = {};
  bool _termoConcordo = false;

  @override
  void initState() {
    super.initState();
    os = widget.os;
    _carregarChecklist();
  }

  @override
  void dispose() {
    for (final c in _justificativas.values) c.dispose();
    for (final c in _respostasTexto.values) c.dispose();
    super.dispose();
  }

  Future<void> _carregarChecklist() async {
    try {
      final resp = await _api.get('/apr/checklist');
      if (resp['success'] == true) {
        final lista = (resp['data'] as List).map((c) => CategoriaApr.fromJson(c)).toList();
        for (final cat in lista) {
          for (final perg in cat.perguntas) {
            if (perg.tipoResposta == 'texto') _respostasTexto[perg.id] = TextEditingController();
            _justificativas[perg.id] = TextEditingController();
          }
        }
        setState(() { _categorias = lista; _carregando = false; });
      } else {
        setState(() { _erro = resp['error'] ?? 'Erro ao carregar checklist'; _carregando = false; });
      }
    } catch (e) {
      setState(() { _erro = 'Erro de conexão: $e'; _carregando = false; });
    }
  }

  bool _validarFormulario() {
    for (final cat in _categorias) {
      for (final perg in cat.perguntas) {
        if (!perg.obrigatorio) continue;

        if (perg.tipoResposta == 'sim_nao') {
          if (!_respostasSN.containsKey(perg.id)) {
            _mostrarErro('Responda: "${perg.pergunta}"');
            return false;
          }
          final resposta = _respostasSN[perg.id]!;
          if (perg.requerJustificativaSe != null &&
              resposta.toLowerCase() == perg.requerJustificativaSe) {
            if ((_justificativas[perg.id]?.text.trim() ?? '').isEmpty) {
              _mostrarErro('Justifique: "${perg.pergunta}"');
              return false;
            }
          }
        }

        if (perg.tipoResposta == 'multipla_escolha' && _episSelecionados.isEmpty) {
          _mostrarErro('Selecione ao menos um EPI/EPC obrigatório');
          return false;
        }

        if (perg.tipoResposta == 'texto' &&
            (_respostasTexto[perg.id]?.text.trim() ?? '').isEmpty) {
          _mostrarErro('Preencha: "${perg.pergunta}"');
          return false;
        }
      }
    }

    if (!_termoConcordo) {
      _mostrarErro('Aceite o termo de responsabilidade para continuar');
      return false;
    }
    return true;
  }

  Future<void> _salvarApr() async {
    if (!_validarFormulario()) return;
    setState(() => _salvando = true);

    try {
      final List<Map<String, dynamic>> respostas = [];

      for (final cat in _categorias) {
        for (final perg in cat.perguntas) {
          if (perg.tipoResposta == 'sim_nao') {
            respostas.add({
              'pergunta_id': perg.id,
              'resposta': _respostasSN[perg.id] ?? '',
              'justificativa': _justificativas[perg.id]?.text.trim(),
            });
          } else if (perg.tipoResposta == 'multipla_escolha') {
            respostas.add({
              'pergunta_id': perg.id,
              'resposta': _episSelecionados.join(','),
              'justificativa': null,
            });
          } else if (perg.tipoResposta == 'texto') {
            respostas.add({
              'pergunta_id': perg.id,
              'resposta': _respostasTexto[perg.id]?.text.trim() ?? '',
              'justificativa': null,
            });
          }
        }
      }

      final resp = await _api.post('/apr/respostas', {
        'os_id': os.id,
        'respostas': respostas,
        'epis_selecionados': _episSelecionados.toList(),
      });

      if (resp['success'] == true) {
        if (mounted) Navigator.pop(context, true);
      } else {
        _mostrarErro(resp['error'] ?? 'Erro ao salvar APR');
      }
    } catch (e) {
      _mostrarErro('Erro: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.orange,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _carregando
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
                    : _erro != null
                    ? _buildErro()
                    : _buildFormulario(),
              ),
            ],
          ),
          if (_salvando)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00FF88)),
                    SizedBox(height: 16),
                    Text('Salvando APR...', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 18, left: 20, right: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFD32F2F), const Color(0xFFD32F2F).withValues(alpha: 0.75)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.settings.name == '/');
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('APR – Análise Preliminar de Risco',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                Text('OS #${os.numeroOs} · Preenchimento obrigatório',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),
        ],
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(_erro!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () { setState(() { _carregando = true; _erro = null; }); _carregarChecklist(); },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
              child: const Text('Tentar novamente', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF3D1515),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade800),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Preencha todas as questões obrigatórias antes de iniciar o serviço.',
                    style: TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          ..._categorias.map((cat) => _buildCategoria(cat)),
          _buildTermo(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _salvando ? null : _salvarApr,
              icon: const Icon(Icons.check_circle, color: Colors.black),
              label: const Text(
                'Confirmar APR e Iniciar Execução',
                style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoria(CategoriaApr cat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88).withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16), topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(_iconeCategoria(cat.ordem), color: const Color(0xFF00FF88), size: 22),
                const SizedBox(width: 10),
                Text(cat.nome, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ...cat.perguntas.asMap().entries.map((e) => Column(
            children: [
              if (e.key > 0) const Divider(color: Colors.white10, height: 1),
              _buildPergunta(e.value),
            ],
          )),
        ],
      ),
    );
  }

  IconData _iconeCategoria(int ordem) {
    switch (ordem) {
      case 1: return Icons.people;
      case 2: return Icons.build_circle;
      case 3: return Icons.dangerous;
      case 4: return Icons.security;
      case 5: return Icons.task_alt;
      default: return Icons.checklist;
    }
  }

  Widget _buildPergunta(PerguntaApr perg) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (perg.obrigatorio)
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 4),
                  child: Text('*', style: TextStyle(color: Colors.red, fontSize: 16)),
                ),
              Expanded(child: Text(perg.pergunta, style: const TextStyle(color: Colors.white, fontSize: 14.5))),
            ],
          ),
          const SizedBox(height: 10),
          if (perg.tipoResposta == 'sim_nao') _buildSimNao(perg),
          if (perg.tipoResposta == 'multipla_escolha') _buildMultiplaEscolha(perg),
          if (perg.tipoResposta == 'texto') _buildTexto(perg),
          if (perg.tipoResposta == 'sim_nao' &&
              perg.requerJustificativaSe != null &&
              _respostasSN[perg.id]?.toLowerCase() == perg.requerJustificativaSe)
            _buildJustificativa(perg),
        ],
      ),
    );
  }

  Widget _buildSimNao(PerguntaApr perg) {
    final resposta = _respostasSN[perg.id];
    return Row(
      children: [
        _buildChip(label: 'SIM', selecionado: resposta == 'SIM', cor: Colors.green, onTap: () => setState(() => _respostasSN[perg.id] = 'SIM')),
        const SizedBox(width: 12),
        _buildChip(label: 'NÃO', selecionado: resposta == 'NAO', cor: Colors.red, onTap: () => setState(() => _respostasSN[perg.id] = 'NAO')),
      ],
    );
  }

  Widget _buildChip({required String label, required bool selecionado, required Color cor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: selecionado ? cor.withValues(alpha: 0.2) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selecionado ? cor : Colors.white24, width: selecionado ? 2 : 1),
        ),
        child: Text(label, style: TextStyle(color: selecionado ? cor : Colors.white54, fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Widget _buildJustificativa(PerguntaApr perg) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        controller: _justificativas[perg.id],
        maxLines: 2,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'Descreva o motivo *',
          labelStyle: const TextStyle(color: Colors.orange),
          filled: true, fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.orange)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.orange)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.orange, width: 2)),
        ),
      ),
    );
  }

  Widget _buildMultiplaEscolha(PerguntaApr perg) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: perg.opcoes.map((opcao) {
        final selecionado = _episSelecionados.contains(opcao.id);
        return GestureDetector(
          onTap: () => setState(() => selecionado ? _episSelecionados.remove(opcao.id) : _episSelecionados.add(opcao.id)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selecionado ? const Color(0xFF00FF88).withValues(alpha: 0.15) : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selecionado ? const Color(0xFF00FF88) : Colors.white24, width: selecionado ? 2 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selecionado) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.check_circle, color: Color(0xFF00FF88), size: 16)),
                Text(opcao.opcao, style: TextStyle(color: selecionado ? const Color(0xFF00FF88) : Colors.white70, fontSize: 13, fontWeight: selecionado ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTexto(PerguntaApr perg) {
    return TextField(
      controller: _respostasTexto[perg.id],
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Digite aqui...',
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true, fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF00FF88), width: 2)),
      ),
    );
  }

  Widget _buildTermo() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _termoConcordo ? const Color(0xFF00FF88) : Colors.white24),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _termoConcordo,
            onChanged: (v) => setState(() => _termoConcordo = v ?? false),
            activeColor: const Color(0xFF00FF88),
            checkColor: Colors.black,
            side: const BorderSide(color: Colors.white54),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Declaro que as informações acima são verdadeiras e me responsabilizo pela execução segura deste serviço.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}