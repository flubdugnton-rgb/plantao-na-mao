# Plantão na Mão para macOS

O mesmo repositório contém o app de iPhone/iPad e o app nativo de Mac. A versão Mac exige macOS 26 e inclui calendário, cadastro/edição/exclusão de plantões, modelos recentes, pagamentos, financeiro, painel, locais, PDFs, lembretes e extensão WidgetKit. A barra lateral, o robô do login e o seletor de temas foram adaptados do Kepleræ, com a identidade do Plantão na Mão.

## Abrir e compilar

1. Instale Xcode 26 e XcodeGen.
2. Execute `python3 scripts/prepare-macos-icon.py` e `xcodegen generate`.
3. Abra `PlantaoNaMao.xcodeproj` e selecione o esquema **PlantaoNaMaoMac**. O esquema **PlantaoNaMao** continua sendo iPhone/iPad.
4. O workflow `.github/workflows/build-macos.yml` testa e gera ZIP/DMG para Apple Silicon e Intel. Ele compila o código diretamente do repositório, sem selecionar ZIPs antigos.

O ícone do Mac é gerado a partir do PNG aprovado do iOS. Não utiliza o ícone do Kepleræ.

## Login e sincronização Google

Não é preciso Apple Developer para usar o login e a sincronização Google no app Mac de teste. Conecte a mesma conta Google em **Ajustes > Conta Google** no iPhone e no login do Mac. Ative a sincronização automática nos aparelhos. Atualize também o iOS para esta revisão, que passa a buscar mudanças do Mac automaticamente.

O Mac usa AppAuth com a janela de autenticação do macOS, PKCE, renovação de token e armazenamento no Chaves, como o Kepleræ. O cliente nativo público reutilizado é `240965240632-g58uffmvvthdqa1mk513fd4k8m8jml2v.apps.googleusercontent.com`. O iOS mantém seu cliente `240965240632-fd5s8htiparn8kk84rpctc1ggrfrur2g.apps.googleusercontent.com`. Ambos pertencem ao projeto Google `240965240632`.

A sessão do Plantão fica em seu próprio serviço do Chaves; não lê tokens salvos pelo Kepleræ. Solicita apenas perfil básico e `drive.appdata`. Os dados usam exclusivamente `plantao-na-mao-sync-v1-<dispositivo>.json`, preservando os arquivos do Kepleræ.

Alterações são enviadas após dois segundos; os apps buscam mudanças do outro aparelho a cada 30 segundos enquanto podem executar e ao retornar. O iOS pausa em segundo plano. O Mac continua buscando enquanto está aberto, inclusive ao usar outra janela, e retoma após repouso. O sistema e a rede podem atrasar a atualização; não existe execução contínua garantida com os apps encerrados.

Cada aparelho mantém uma cópia local. Edições offline são conciliadas ao reconectar; exclusões são mantidas para impedir que cópias antigas recuperem plantões apagados. Conta vinculada, dados inválidos e falhas de permissão são verificados antes de mesclar dados. Sair da conta preserva os plantões locais.

## Widgets nativos e assinatura Apple

A extensão do Mac renderiza o mesmo calendário com aros do iOS em três tamanhos, muda dia/mês pela timeline e abre o app na data escolhida. Salvar, editar, excluir, sincronizar e alterar a aparência solicita uma atualização do widget. A frequência final é controlada pelo WidgetKit.

Para o widget instalado acessar o calendário do app, **app e extensão precisam da mesma equipe de assinatura e de um App Group autorizado**. O projeto declara `group.com.plantaonamao.shared`. No Xcode, selecione sua equipe Apple nos targets **PlantaoNaMaoMac** e **PlantaoNaMaoMacWidgets**, configure o grupo autorizado e assine ambos. Caso o grupo tenha outro identificador, ajuste `APP_GROUP_IDENTIFIER` antes de gerar o projeto.

O pacote automático tem assinatura ad hoc para testes, sem certificado Apple do proprietário. Compilar a extensão e colocá-la no app não concede autorização ao App Group. Portanto, esse pacote **não comprova funcionamento do compartilhamento do widget instalado**. Sem a assinatura Apple necessária, não é possível prometer que o widget nativo terá acesso aos dados, mesmo que o Google sincronize o app normalmente. Não são solicitadas chaves privadas, senhas ou certificados nesta entrega.

Em **Perfil e ajustes > Widgets do Mac**, “O widget confirmou a leitura…” aparece somente após a extensão ler o calendário correto. Gravar o calendário no app não gera uma confirmação falsa.

## Validação

Os testes verificam conciliação de dados de dois aparelhos, exclusões, campos financeiros, HTTP do Drive com respostas simuladas, privacidade da projeção dos widgets, PDFs paginados, lembretes e interface nativa. Testes de interface usam dados de demonstração apenas em Debug com argumentos de teste; o login de produção exige Google real.

Login OAuth real, sincronização entre o iPhone do proprietário e o Mac e autorização do widget instalado precisam ser verificados nos aparelhos. Os testes automatizados e a compilação não substituem essas confirmações.

Referências: [Google Drive — dados privados do app](https://developers.google.com/workspace/drive/api/guides/appdata), [AppAuth macOS](https://github.com/openid/AppAuth-iOS), [Apple — App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups), [Apple — atualização dos widgets](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date).
