<?php
/* =========================================================
   Tear Brechó — API de sincronização do painel
   Guarda os dados FORA do public_html (pasta tear_dados),
   para ninguém conseguir baixar o arquivo pela internet.
   ========================================================= */
error_reporting(0);
header('X-Content-Type-Options: nosniff');

/* ---------- localizar pasta de dados ---------- */
function pasta_dados(){
  $p = __DIR__;
  while ($p !== '/' && $p !== '' && basename($p) !== 'public_html') { $p = dirname($p); }
  $raiz = (basename($p) === 'public_html') ? dirname($p) : dirname(__DIR__);
  $base = $raiz . '/tear_dados';
  if (!is_dir($base)) { @mkdir($base, 0750, true); }
  if (!is_dir($base) || !is_writable($base)) {
    // plano B: dentro da pasta do site, bloqueada por .htaccess
    $base = __DIR__ . '/_dados';
    if (!is_dir($base)) { @mkdir($base, 0750, true); }
    @file_put_contents($base . '/.htaccess', "Require all denied\nDeny from all\n");
  }
  foreach (['fotos', 'backups'] as $d) { if (!is_dir("$base/$d")) { @mkdir("$base/$d", 0750, true); } }
  return $base;
}
$BASE = pasta_dados();
$F_CONFIG = "$BASE/config.json";
$F_TOKENS = "$BASE/tokens.json";
$F_DB     = "$BASE/db.json";
$F_TENT   = "$BASE/tentativas.json";
// senha inicial do painel (hash bcrypt) — pode ser trocada pelo próprio painel
const HASH_SENHA_INICIAL = '$2y$10$vUwWGjUHEyc3uXkFQLjqeexNrb6cc2JTjdWuu8ZedxwWEL.jkNuT6';
function config_atual(){ global $F_CONFIG; $c = ler_json($F_CONFIG, []); if (empty($c['hash'])) $c['hash'] = HASH_SENHA_INICIAL; return $c; }

/* ---------- helpers ---------- */
function out($arr, $code = 200){
  http_response_code($code);
  header('Content-Type: application/json; charset=utf-8');
  header('Cache-Control: no-store');
  echo json_encode($arr, JSON_UNESCAPED_UNICODE);
  exit;
}
function ler_json($f, $padrao){
  if (!file_exists($f)) return $padrao;
  $j = json_decode(@file_get_contents($f), true);
  return is_array($j) ? $j : $padrao;
}
function gravar_json($f, $dados){
  $tmp = $f . '.tmp' . bin2hex(random_bytes(4));
  if (@file_put_contents($tmp, json_encode($dados, JSON_UNESCAPED_UNICODE)) === false) return false;
  return @rename($tmp, $f);
}
function corpo(){
  static $b = null;
  if ($b === null) { $b = json_decode(file_get_contents('php://input'), true); if (!is_array($b)) $b = []; }
  return $b;
}
function token_req(){
  if (!empty($_SERVER['HTTP_X_TOKEN'])) return $_SERVER['HTTP_X_TOKEN'];
  $b = corpo();
  return isset($b['token']) ? $b['token'] : (isset($_GET['token']) ? $_GET['token'] : '');
}
function autenticado(){
  global $F_TOKENS;
  $t = token_req();
  if (!$t || !preg_match('/^[a-f0-9]{64}$/', $t)) return false;
  $tokens = ler_json($F_TOKENS, []);
  $h = hash('sha256', $t);
  return isset($tokens[$h]) && $tokens[$h] > time();
}
function exigir_login(){ if (!autenticado()) out(['erro' => 'nao_autenticado'], 401); }
function novo_token(){
  global $F_TOKENS;
  $t = bin2hex(random_bytes(32));
  $tokens = ler_json($F_TOKENS, []);
  $agora = time();
  foreach ($tokens as $k => $exp) { if ($exp < $agora) unset($tokens[$k]); }
  $tokens[hash('sha256', $t)] = $agora + 86400 * 180; // 180 dias
  gravar_json($F_TOKENS, $tokens);
  return $t;
}
function ip(){ return isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : 'x'; }
function bloqueado(){
  global $F_TENT;
  $t = ler_json($F_TENT, []);
  $i = ip();
  return isset($t[$i]) && $t[$i]['n'] >= 8 && (time() - $t[$i]['t']) < 900;
}
function registrar_falha(){
  global $F_TENT;
  $t = ler_json($F_TENT, []);
  $i = ip();
  if (!isset($t[$i]) || (time() - $t[$i]['t']) > 900) $t[$i] = ['n' => 0, 't' => time()];
  $t[$i]['n']++; $t[$i]['t'] = time();
  gravar_json($F_TENT, $t);
}
function limpar_falhas(){
  global $F_TENT;
  $t = ler_json($F_TENT, []); unset($t[ip()]); gravar_json($F_TENT, $t);
}

$acao = isset($_GET['acao']) ? $_GET['acao'] : '';

/* ---------- servir foto (público, para o catálogo) ---------- */
if ($acao === 'foto') {
  $n = isset($_GET['n']) ? $_GET['n'] : '';
  if (!preg_match('/^[a-zA-Z0-9_-]{6,80}\.(jpg|png|webp)$/', $n)) { http_response_code(404); exit; }
  $f = "$BASE/fotos/$n";
  if (!file_exists($f)) { http_response_code(404); exit; }
  $ext = pathinfo($n, PATHINFO_EXTENSION);
  $mime = ['jpg' => 'image/jpeg', 'png' => 'image/png', 'webp' => 'image/webp'][$ext];
  header("Content-Type: $mime");
  header('Cache-Control: public, max-age=31536000, immutable');
  header('Content-Length: ' . filesize($f));
  readfile($f);
  exit;
}

switch ($acao) {

  case 'status':
    $cfg = config_atual();
    out(['configurado' => !empty($cfg['hash']), 'autenticado' => autenticado()]);

  case 'criar_senha':
    $cfg = config_atual();
    if (!empty($cfg['hash'])) out(['erro' => 'ja_configurado'], 403);
    $s = (string)(corpo()['senha'] ?? '');
    if (mb_strlen($s) < 6) out(['erro' => 'senha_curta'], 400);
    $cfg['hash'] = password_hash($s, PASSWORD_DEFAULT);
    $cfg['criadoEm'] = date('c');
    if (!gravar_json($F_CONFIG, $cfg)) out(['erro' => 'sem_permissao_gravar'], 500);
    out(['ok' => true, 'token' => novo_token()]);

  case 'login':
    if (bloqueado()) out(['erro' => 'muitas_tentativas'], 429);
    $cfg = config_atual();
    $s = (string)(corpo()['senha'] ?? '');
    if (empty($cfg['hash']) || !password_verify($s, $cfg['hash'])) { registrar_falha(); usleep(700000); out(['erro' => 'senha_incorreta'], 401); }
    limpar_falhas();
    out(['ok' => true, 'token' => novo_token()]);

  case 'trocar_senha':
    exigir_login();
    $cfg = config_atual();
    $b = corpo();
    if (!password_verify((string)($b['atual'] ?? ''), $cfg['hash'])) out(['erro' => 'senha_incorreta'], 401);
    $nova = (string)($b['nova'] ?? '');
    if (mb_strlen($nova) < 6) out(['erro' => 'senha_curta'], 400);
    $cfg['hash'] = password_hash($nova, PASSWORD_DEFAULT);
    gravar_json($F_CONFIG, $cfg);
    gravar_json($F_TOKENS, []); // desconecta todos os aparelhos
    out(['ok' => true, 'token' => novo_token()]);

  case 'sair':
    $t = token_req();
    $tokens = ler_json($F_TOKENS, []);
    unset($tokens[hash('sha256', $t)]);
    gravar_json($F_TOKENS, $tokens);
    out(['ok' => true]);

  case 'dados':
    exigir_login();
    $db = ler_json($F_DB, ['versao' => 0, 'atualizadoEm' => null, 'dados' => null]);
    out($db);

  case 'salvar':
    exigir_login();
    $b = corpo();
    if (!isset($b['dados']) || !is_array($b['dados'])) out(['erro' => 'dados_invalidos'], 400);
    $lock = fopen("$BASE/.lock", 'c');
    flock($lock, LOCK_EX);
    $db = ler_json($F_DB, ['versao' => 0, 'atualizadoEm' => null, 'dados' => null]);
    $base = isset($b['versaoBase']) ? (int)$b['versaoBase'] : -1;
    if (empty($b['forcar']) && $base !== (int)$db['versao']) {
      flock($lock, LOCK_UN);
      out(['erro' => 'conflito', 'versao' => $db['versao'], 'atualizadoEm' => $db['atualizadoEm'], 'dados' => $db['dados']], 409);
    }
    // backup da versão anterior (mantém os 80 mais recentes)
    if (file_exists($F_DB)) {
      @copy($F_DB, "$BASE/backups/db-" . date('Ymd-His') . '-v' . $db['versao'] . '.json');
      $bks = glob("$BASE/backups/db-*.json");
      if ($bks && count($bks) > 80) { sort($bks); foreach (array_slice($bks, 0, count($bks) - 80) as $old) @unlink($old); }
    }
    $novo = ['versao' => (int)$db['versao'] + 1, 'atualizadoEm' => date('c'), 'aparelho' => substr((string)($b['aparelho'] ?? ''), 0, 60), 'dados' => $b['dados']];
    $ok = gravar_json($F_DB, $novo);
    flock($lock, LOCK_UN);
    if (!$ok) out(['erro' => 'sem_permissao_gravar'], 500);
    out(['ok' => true, 'versao' => $novo['versao'], 'atualizadoEm' => $novo['atualizadoEm']]);

  case 'versao':
    exigir_login();
    $db = ler_json($F_DB, ['versao' => 0, 'atualizadoEm' => null]);
    out(['versao' => $db['versao'], 'atualizadoEm' => $db['atualizadoEm']]);

  case 'enviar_foto':
    exigir_login();
    $img = (string)(corpo()['imagem'] ?? '');
    if (!preg_match('/^data:image\/(jpeg|png|webp);base64,(.+)$/', $img, $m)) out(['erro' => 'formato_invalido'], 400);
    $bin = base64_decode($m[2], true);
    if ($bin === false || strlen($bin) > 6 * 1024 * 1024) out(['erro' => 'imagem_grande'], 400);
    if (function_exists('getimagesizefromstring') && !@getimagesizefromstring($bin)) out(['erro' => 'imagem_invalida'], 400);
    $ext = $m[1] === 'jpeg' ? 'jpg' : $m[1];
    $nome = 'f' . date('ymdHis') . '_' . bin2hex(random_bytes(6)) . '.' . $ext;
    if (@file_put_contents("$BASE/fotos/$nome", $bin) === false) out(['erro' => 'sem_permissao_gravar'], 500);
    out(['ok' => true, 'nome' => $nome]);

  case 'feed':
    // Lista de produtos para o robô do WhatsApp (precisa do token de login)
    exigir_login();
    $db = ler_json($F_DB, ['versao' => 0, 'dados' => null]);
    $d = is_array($db['dados']) ? $db['dados'] : [];
    $marcas = [];
    foreach (($d['marcas'] ?? []) as $m) { $marcas[(string)$m['id']] = $m['nome']; }
    $esquema = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $baseUrl = $esquema . '://' . $_SERVER['HTTP_HOST'] . rtrim(dirname($_SERVER['SCRIPT_NAME']), '/\\') . '/api.php?acao=foto&n=';
    $todos = isset($_GET['todos']);
    $lista = [];
    foreach (($d['produtos'] ?? []) as $p) {
      $estoque = (int)($p['estoque'] ?? 0);
      $status = ($p['status'] ?? '') === 'Inativo' ? 'Inativo' : ($estoque <= 0 ? 'Vendido' : (($p['status'] ?? '') === 'Reservado' ? 'Reservado' : 'Disponivel'));
      $publicar = !isset($p['publicarWhatsapp']) || $p['publicarWhatsapp'] !== false;
      if (!$todos && ($status !== 'Disponivel' || !$publicar)) continue;
      $promo = (float)($p['precoPromo'] ?? 0);
      $venda = (float)($p['precoVenda'] ?? 0);
      $lista[] = [
        'id' => $p['id'], 'codigo' => $p['codigo'] ?? '', 'sku' => $p['sku'] ?? '',
        'nome' => $p['nome'] ?? '', 'descricao' => $p['descricao'] ?? '',
        'marca' => isset($p['marcaId']) && isset($marcas[(string)$p['marcaId']]) ? $marcas[(string)$p['marcaId']] : '',
        'categoria' => $p['categoria'] ?? '', 'tamanho' => $p['variacoes'] ?? '', 'estado' => $p['estado'] ?? '',
        'cor' => $p['cor'] ?? '', 'tecido' => $p['material'] ?? '', 'epoca' => $p['epoca'] ?? '',
        'medidas' => $p['medidas'] ?? new stdClass(),
        'preco' => $venda, 'precoPromocional' => ($promo > 0 && $promo < $venda) ? $promo : null,
        'precoFinal' => ($promo > 0 && $promo < $venda) ? $promo : $venda,
        'estoque' => $estoque, 'status' => $status, 'publicarWhatsapp' => $publicar,
        'publicadoWhatsappEm' => $p['publicadoWhatsappEm'] ?? null,
        'fotos' => array_map(function($n) use ($baseUrl) { return $baseUrl . rawurlencode($n); }, $p['fotos'] ?? []),
        'dataEntrada' => $p['dataEntrada'] ?? '', 'tags' => $p['tags'] ?? ''
      ];
    }
    out(['versao' => $db['versao'], 'atualizadoEm' => $db['atualizadoEm'] ?? null, 'total' => count($lista), 'produtos' => $lista]);

  case 'marcar_publicado':
    // O robô avisa quais produtos já foram enviados ao grupo
    exigir_login();
    $ids = corpo()['ids'] ?? [];
    if (!is_array($ids) || !$ids) out(['erro' => 'ids_vazios'], 400);
    $lock = fopen("$BASE/.lock", 'c');
    flock($lock, LOCK_EX);
    $db = ler_json($F_DB, ['versao' => 0, 'dados' => null]);
    $n = 0; $agora = date('c');
    foreach ($db['dados']['produtos'] as &$p) { if (in_array($p['id'], $ids)) { $p['publicadoWhatsappEm'] = $agora; $n++; } }
    unset($p);
    @copy($F_DB, "$BASE/backups/db-" . date('Ymd-His') . '-v' . $db['versao'] . '.json');
    $db['versao'] = (int)$db['versao'] + 1; $db['atualizadoEm'] = $agora; $db['aparelho'] = 'robo-whatsapp';
    gravar_json($F_DB, $db);
    flock($lock, LOCK_UN);
    out(['ok' => true, 'marcados' => $n, 'versao' => $db['versao']]);

  default:
    out(['erro' => 'acao_desconhecida'], 404);
}
