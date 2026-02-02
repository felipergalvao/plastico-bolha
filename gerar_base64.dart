import 'dart:io';
import 'dart:convert';

void main() {
  print('📢 O SCRIPT ESTÁ RODANDO! (Se ler isso, o console funciona)');
  
  // Tenta descobrir onde estamos
  var diretorioAtual = Directory.current.path;
  print('📂 Pasta atual: $diretorioAtual');

  // Ajuste o nome do arquivo se for diferente
  var nomeArquivo = 'upload-keystore.jks'; 
  var caminhosTentativa = [
    'android/app/$nomeArquivo', // Caminho padrão
    '$nomeArquivo',             // Talvez esteja na raiz?
    'app/$nomeArquivo'          // Variação
  ];

  File? arquivoEncontrado;

  for (var caminho in caminhosTentativa) {
    var f = File(caminho);
    if (f.existsSync()) {
      arquivoEncontrado = f;
      print('✅ ACHEI A CHAVE EM: $caminho');
      break;
    } else {
      print('❌ Não achei em: $caminho');
    }
  }

  if (arquivoEncontrado != null) {
    try {
      final bytes = arquivoEncontrado.readAsBytesSync();
      final base64String = base64Encode(bytes);
      print('\n👇 --- COPIE O CÓDIGO ABAIXO (Cuidado para selecionar tudo) --- 👇\n');
      print(base64String); // <--- AQUI ESTÁ O CÓDIGO GIGANTE
      print('\n👆 ----------------------------------------------------------- 👆\n');
    } catch (e) {
      print('🔥 Erro ao ler o arquivo: $e');
    }
  } else {
    print('\n⚠️ SOCORRO: Não encontrei o arquivo "$nomeArquivo".');
    print('Verifique se você já criou a keystore e se o nome está certo.');
  }
}
