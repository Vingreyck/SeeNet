// lib/ordem_de_servico/screens/apr_screen.dart — REDESIGN
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/api_service.dart';
import '../../models/ordem_servico_model.dart';
import 'package:get_storage/get_storage.dart';
import '../../services/connectivity_service.dart';
import '../../services/sync_manager.dart';

// ── Modelos (inalterados) ────────────────────────────────────────

class CategoriaApr {
  final int id;
  final String nome;
  final int ordem;
  final List<PerguntaApr> perguntas;

  CategoriaApr({required this.id, required this.nome, required this.ordem, required this.perguntas});

  factory CategoriaApr.fromJson(Map<String, dynamic> json) => CategoriaApr(
    id: json['id'], nome: json['nome'], ordem: json['ordem'],
    perguntas: (json['perguntas'] as List).map((p) => PerguntaApr.fromJson(p)).toList(),
  );
}

class PerguntaApr {
  final int id;
  final int categoriaId;
  final String pergunta;
  final String tipoResposta;
  final bool obrigatorio;
  final String? requerJustificativaSe;
  final List<OpcaoApr> opcoes;

  PerguntaApr({
    required this.id, required this.categoriaId, required this.pergunta,
    required this.tipoResposta, required this.obrigatorio,
    this.requerJustificativaSe, required this.opcoes,
  });

  factory PerguntaApr.fromJson(Map<String, dynamic> json) => PerguntaApr(
    id: json['id'], categoriaId: json['categoria_id'],
    pergunta: json['pergunta'], tipoResposta: json['tipo_resposta'],
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

// ── Tela APR ─────────────────────────────────────────────────────

class AprScreen extends StatefulWidget {
  final OrdemServico os;
  const AprScreen({super.key, required this.os});

  @override
  State<AprScreen> createState() => _AprScreenState();
}

class _AprScreenState extends State<AprScreen>
    with WidgetsBindingObserver {
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

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

  @override
  void initState() {
    super.initState();
    os = widget.os;
    WidgetsBinding.instance.addObserver(this); // salva rascunho ao minimizar/fechar
    _carregarChecklist();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _justificativas.values) c.dispose();
    for (final c in _respostasTexto.values) c.dispose();
    super.dispose();
  }

  // ✅ Salva o rascunho do APR quando o app vai pro fundo (minimizar/fechar) —
  // assim o técnico NÃO precisa refazer o APR se sair no meio.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _salvarRascunho();
    }
    super.didChangeAppLifecycleState(state);
  }

  String get _rascunhoKey => 'apr_rascunho_${os.id}';

  void _salvarRascunho() {
    if (_categorias.isEmpty) return; // nada carregado ainda
    GetStorage().write(_rascunhoKey, {
      'sn': _respostasSN.map((k, v) => MapEntry(k.toString(), v)),
      'just': {
        for (final e in _justificativas.entries) e.key.toString(): e.value.text
      },
      'texto': {
        for (final e in _respostasTexto.entries) e.key.toString(): e.value.text
      },
      'epis': _episSelecionados.toList(),
      'termo': _termoConcordo,
    });
  }

  // Restaura o rascunho (chamar DEPOIS de criar os controllers do checklist).
  void _restaurarRascunho() {
    final d = GetStorage().read<Map>(_rascunhoKey);
    if (d == null) return;
    (d['sn'] as Map?)?.forEach((k, v) {
      final id = int.tryParse(k.toString());
      if (id != null) _respostasSN[id] = v.toString();
    });
    (d['just'] as Map?)?.forEach((k, v) {
      final id = int.tryParse(k.toString());
      if (id != null && _justificativas[id] != null) {
        _justificativas[id]!.text = v.toString();
      }
    });
    (d['texto'] as Map?)?.forEach((k, v) {
      final id = int.tryParse(k.toString());
      if (id != null && _respostasTexto[id] != null) {
        _respostasTexto[id]!.text = v.toString();
      }
    });
    for (final e in (d['epis'] as List?) ?? const []) {
      final id = int.tryParse(e.toString());
      if (id != null) _episSelecionados.add(id);
    }
    _termoConcordo = (d['termo'] as bool?) ?? false;
  }

  void _limparRascunho() => GetStorage().remove(_rascunhoKey);

  Future<void> _carregarChecklist() async {
    try {
      final resp = await _api.get('/apr/checklist');
      if (resp['success'] == true) {
        // ✅ Salva cache para uso offline
        GetStorage().write('apr_checklist_cache', resp['data']);
        final lista = (resp['data'] as List)
            .map((c) => CategoriaApr.fromJson(c)).toList();
        for (final cat in lista) {
          for (final perg in cat.perguntas) {
            if (perg.tipoResposta == 'texto')
              _respostasTexto[perg.id] = TextEditingController();
            _justificativas[perg.id] = TextEditingController();
          }
        }
        _restaurarRascunho(); // ✅ traz de volta o que o técnico já preencheu
        setState(() { _categorias = lista; _carregando = false; });
      } else {
        _carregarDoCache();
      }
    } catch (e) {
      _carregarDoCache();
    }
  }

  void _carregarDoCache() {
    final cache = GetStorage().read<List>('apr_checklist_cache');
    if (cache != null) {
      final lista = cache
          .map((c) => CategoriaApr.fromJson(Map<String, dynamic>.from(c)))
          .toList();
      for (final cat in lista) {
        for (final perg in cat.perguntas) {
          if (perg.tipoResposta == 'texto')
            _respostasTexto[perg.id] = TextEditingController();
          _justificativas[perg.id] = TextEditingController();
        }
      }
      if (mounted) {
        _restaurarRascunho(); // ✅ traz de volta o que o técnico já preencheu
        setState(() { _categorias = lista; _carregando = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('📶 Sem conexão — usando checklist salvo'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ));
      }
    } else {
      if (mounted) setState(() {
        _erro = 'Sem conexão e sem checklist em cache.\nConecte-se à internet ao menos uma vez.';
        _carregando = false;
      });
    }
  }

  bool _validarFormulario() {
    for (final cat in _categorias) {
      for (final perg in cat.perguntas) {
        if (!perg.obrigatorio) continue;
        if (perg.tipoResposta == 'sim_nao') {
          if (!_respostasSN.containsKey(perg.id)) {
            _mostrarErro('Responda: "${perg.pergunta}"'); return false;
          }
          final resposta = _respostasSN[perg.id]!;
          if (perg.requerJustificativaSe != null &&
              resposta.toLowerCase() == perg.requerJustificativaSe) {
            if ((_justificativas[perg.id]?.text.trim() ?? '').isEmpty) {
              _mostrarErro('Justifique: "${perg.pergunta}"'); return false;
            }
          }
        }
        if (perg.tipoResposta == 'multipla_escolha' &&
            _episSelecionados.isEmpty) {
          _mostrarErro('Selecione ao menos um EPI/EPC obrigatório');
          return false;
        }
        if (perg.tipoResposta == 'texto' &&
            (_respostasTexto[perg.id]?.text.trim() ?? '').isEmpty) {
          _mostrarErro('Preencha: "${perg.pergunta}"'); return false;
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
      // ✅ Offline: enfileira localmente
      final connectivity = Get.find<ConnectivityService>();
      if (connectivity.offline) {
        final List<Map<String, dynamic>> respostasOffline = [];
        for (final cat in _categorias) {
          for (final perg in cat.perguntas) {
            if (perg.tipoResposta == 'sim_nao') {
              respostasOffline.add({
                'pergunta_id': perg.id,
                'resposta': _respostasSN[perg.id] ?? '',
                'justificativa': _justificativas[perg.id]?.text.trim(),
              });
            } else if (perg.tipoResposta == 'multipla_escolha') {
              respostasOffline.add({
                'pergunta_id': perg.id,
                'resposta': _episSelecionados.join(','),
                'justificativa': null,
              });
            } else if (perg.tipoResposta == 'texto') {
              respostasOffline.add({
                'pergunta_id': perg.id,
                'resposta': _respostasTexto[perg.id]?.text.trim() ?? '',
                'justificativa': null,
              });
            }
          }
        }
        await Get.find<SyncManager>().enfileirarSalvarAPR(
            os.id.toString(), respostasOffline, _episSelecionados.toList());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('📥 APR salvo localmente — será enviado quando voltar o sinal'),
            backgroundColor: Colors.orange,
          ));
          _limparRascunho();
          Navigator.pop(context, true);
        }
        return;
      }
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
        _limparRascunho();
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

  IconData _iconeCategoria(int ordem) {
    switch (ordem) {
      case 1: return Icons.people_outline_rounded;
      case 2: return Icons.build_circle_outlined;
      case 3: return Icons.dangerous_outlined;
      case 4: return Icons.security_outlined;
      case 5: return Icons.task_alt_rounded;
      default: return Icons.checklist_rounded;
    }
  }

  // ── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _carregando
                    ? const Center(child: CircularProgressIndicator(
                    color: Color(0xFF00FF88), strokeWidth: 2.5))
                    : _erro != null
                    ? _buildErro()
                    : _buildFormulario(),
              ),
            ],
          ),
          if (_salvando)
            Container(
              color: Colors.black.withOpacity(0.75),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF00FF88).withOpacity(0.2)),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          color: Color(0xFF00FF88), strokeWidth: 2.5),
                      SizedBox(height: 16),
                      Text('Salvando APR...',
                          style: TextStyle(color: Colors.white, fontSize: 15)),
                    ],
                  ),
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
        bottom: 16, left: 12, right: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade900,
            Colors.red.shade900.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 16),
                    SizedBox(width: 6),
                    Text('APR – Análise de Risco',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('OS #${os.numeroOs} · Preenchimento obrigatório',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
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
            Icon(Icons.error_outline_rounded,
                color: Colors.red.withOpacity(0.6), size: 56),
            const SizedBox(height: 14),
            const Text('Erro ao carregar',
                style: TextStyle(color: Colors.white,
                    fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_erro!,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() { _carregando = true; _erro = null; });
                _carregarChecklist();
              },
              icon: const Icon(Icons.refresh_rounded, color: Colors.black),
              label: const Text('Tentar novamente',
                  style: TextStyle(color: Colors.black,
                      fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de aviso
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 18),
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
          const SizedBox(height: 16),

          ..._categorias.map((cat) => _buildCategoria(cat)),

          _buildTermo(),
          const SizedBox(height: 20),

          // Botão confirmar
          GestureDetector(
            onTap: _salvando ? null : _salvarApr,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF00FF88), Color(0xFF00CC6A)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF88).withOpacity(0.3),
                    blurRadius: 16, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.black, size: 20),
                  SizedBox(width: 10),
                  Text('Confirmar APR e Iniciar Execução',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoria(CategoriaApr cat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header da categoria
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88).withOpacity(0.07),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16)),
              border: const Border(
                  bottom: BorderSide(
                      color: Color(0xFF00FF88), width: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_iconeCategoria(cat.ordem),
                      color: const Color(0xFF00FF88), size: 16),
                ),
                const SizedBox(width: 10),
                Text(cat.nome,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${cat.perguntas.length}',
                      style: const TextStyle(
                          color: Color(0xFF00FF88),
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          // Perguntas
          ...cat.perguntas.asMap().entries.map((e) => Column(
            children: [
              if (e.key > 0)
                Divider(
                    color: Colors.white.withOpacity(0.05),
                    height: 1),
              _buildPergunta(e.value),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildPergunta(PerguntaApr perg) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (perg.obrigatorio)
                const Padding(
                  padding: EdgeInsets.only(top: 1, right: 5),
                  child: Text('*',
                      style: TextStyle(
                          color: Color(0xFF00FF88), fontSize: 14)),
                ),
              Expanded(
                child: Text(perg.pergunta,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (perg.tipoResposta == 'sim_nao') _buildSimNao(perg),
          if (perg.tipoResposta == 'multipla_escolha')
            _buildMultiplaEscolha(perg),
          if (perg.tipoResposta == 'texto') _buildTexto(perg),
          if (perg.tipoResposta == 'sim_nao' &&
              perg.requerJustificativaSe != null &&
              _respostasSN[perg.id]?.toLowerCase() ==
                  perg.requerJustificativaSe)
            _buildJustificativa(perg),
        ],
      ),
    );
  }

  Widget _buildSimNao(PerguntaApr perg) {
    final resposta = _respostasSN[perg.id];
    return Row(
      children: [
        _buildChip(label: 'SIM', selecionado: resposta == 'SIM',
            cor: const Color(0xFF00FF88),
            onTap: () => setState(
                    () => _respostasSN[perg.id] = 'SIM')),
        const SizedBox(width: 10),
        _buildChip(label: 'NÃO', selecionado: resposta == 'NAO',
            cor: Colors.red,
            onTap: () => setState(
                    () => _respostasSN[perg.id] = 'NAO')),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required bool selecionado,
    required Color cor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: 22, vertical: 9),
        decoration: BoxDecoration(
          color: selecionado
              ? cor.withOpacity(0.15)
              : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selecionado ? cor : Colors.white12,
              width: selecionado ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                color: selecionado ? cor : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      ),
    );
  }

  Widget _buildJustificativa(PerguntaApr perg) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        controller: _justificativas[perg.id],
        maxLines: 2,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: 'Descreva o motivo *',
          labelStyle: const TextStyle(
              color: Colors.orange, fontSize: 12),
          filled: true,
          fillColor: const Color(0xFF111111),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Colors.orange, width: 1.5)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Colors.orange, width: 1)),
        ),
      ),
    );
  }

  Widget _buildMultiplaEscolha(PerguntaApr perg) {
    return Wrap(
      spacing: 7, runSpacing: 7,
      children: perg.opcoes.map((opcao) {
        final selecionado = _episSelecionados.contains(opcao.id);
        return GestureDetector(
          onTap: () => setState(() => selecionado
              ? _episSelecionados.remove(opcao.id)
              : _episSelecionados.add(opcao.id)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selecionado
                  ? const Color(0xFF00FF88).withOpacity(0.12)
                  : const Color(0xFF111111),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: selecionado
                      ? const Color(0xFF00FF88)
                      : Colors.white12,
                  width: selecionado ? 1.5 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selecionado) ...[
                  const Icon(Icons.check_rounded,
                      color: Color(0xFF00FF88), size: 13),
                  const SizedBox(width: 5),
                ],
                Text(opcao.opcao,
                    style: TextStyle(
                        color: selecionado
                            ? const Color(0xFF00FF88)
                            : Colors.white54,
                        fontSize: 12,
                        fontWeight: selecionado
                            ? FontWeight.bold
                            : FontWeight.normal)),
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
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Digite aqui...',
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: const Color(0xFF111111),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: Colors.white.withOpacity(0.08))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: Color(0xFF00FF88), width: 1.5)),
      ),
    );
  }

  Widget _buildTermo() {
    return GestureDetector(
      onTap: () => setState(() => _termoConcordo = !_termoConcordo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _termoConcordo
              ? const Color(0xFF00FF88).withOpacity(0.07)
              : const Color(0xFF181818),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _termoConcordo
                ? const Color(0xFF00FF88).withOpacity(0.4)
                : Colors.white12,
            width: _termoConcordo ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: _termoConcordo
                    ? const Color(0xFF00FF88)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _termoConcordo
                      ? const Color(0xFF00FF88)
                      : Colors.white24,
                  width: 1.5,
                ),
              ),
              child: _termoConcordo
                  ? const Icon(Icons.check_rounded,
                  color: Colors.black, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Declaro que as informações acima são verdadeiras e me responsabilizo pela execução segura deste serviço.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}