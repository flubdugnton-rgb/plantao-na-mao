# Sincronização Google · iOS e macOS

As duas versões usam a pasta privada `appDataFolder` do mesmo projeto Google Cloud `240965240632`. Não precisam de Apple Developer para sincronizar os plantões pelo Google. A assinatura dos widgets é uma configuração independente.

- iOS: cliente público `240965240632-fd5s8htiparn8kk84rpctc1ggrfrur2g.apps.googleusercontent.com`, SDK Google Sign-In 10.1.0.
- Mac: cliente público do Kepleræ `240965240632-g58uffmvvthdqa1mk513fd4k8m8jml2v.apps.googleusercontent.com`, AppAuth 3.0.0/GTMAppAuth 6.0.0, PKCE e Chaves do macOS. Credenciais salvas separadamente do Kepleræ.
- Escopo de arquivos: somente `https://www.googleapis.com/auth/drive.appdata`.
- Arquivos do Plantão: `plantao-na-mao-sync-v1-<UUID do dispositivo>.json`, schema 2; schema 1 continua migrando. Os arquivos do Kepleræ têm outro nome e não são carregados pelo Plantão.

## Ativação

Ative a Google Drive API e o escopo `drive.appdata` na tela de consentimento do projeto que contém os clientes acima. Se o projeto Google estiver em testes, a conta usada precisa constar entre os usuários de teste. Os client IDs são públicos; não há client secret no aplicativo.

Conecte a mesma conta nos dois aparelhos e ative a sincronização automática. Instale esta revisão também no iOS para buscar alterações feitas no Mac automaticamente. O esquema de retorno OAuth está em `project.yml`. Configuração de outro cliente/projeto exige alterar ambos os aparelhos; apenas usar o mesmo e-mail em projetos Google diferentes não garante acesso à mesma pasta privada.

## Funcionamento

- Edições locais são agrupadas e enviadas depois de dois segundos.
- O app busca alterações remotas ao retornar e a cada 30 segundos enquanto estiver em execução. O Mac mantém a busca ao usar outra janela. O iOS pode suspender o app em segundo plano.
- A busca não envia novamente snapshots idênticos nem recarrega widgets quando não há alteração de dados.
- O botão **Sincronizar agora** antecipa a operação.
- Cada instalação grava apenas seu arquivo e lê os arquivos dos outros aparelhos. Edições simultâneas usam UUID, data de modificação e desempate determinístico.
- Exclusões são preservadas em marcadores, impedindo recuperação por snapshots antigos.
- Nome, local, data, horários, cor, observações, valor, cálculo por hora, previsão e situação de pagamento são sincronizados. Aparência, preferências de lembrete e percentuais escolhidos no financeiro são locais.
- Falhas de rede, conta, permissão, leitura ou schema preservam os registros locais. Edits durante uma transferência ficam pendentes para a próxima operação.
- O banco fica vinculado à conta original para evitar misturar registros ao trocar de conta. Sair desconecta a sessão e mantém os dados.
- Os widgets leem o calendário publicado pelo app no mesmo aparelho. Google não substitui a autorização Apple do App Group.

## Validação real

Os testes automatizados cobrem snapshots entre dispositivos, exclusões, regras financeiras e chamadas HTTP simuladas. Para validar a conta real: crie um plantão no iPhone, confira no Mac, edite o pagamento no Mac e confira no iPhone, depois exclua e confirme nos dois. Teste também uma edição offline seguida de reconexão. A execução com apps encerrados e a atualização imediata do widget não são garantidas pelo sistema.

Leia [MACOS_SETUP.md](MACOS_SETUP.md) e [WIDGETS_SETUP.md](WIDGETS_SETUP.md) para assinatura e diagnóstico dos widgets.

Referências: [dados privados no Google Drive](https://developers.google.com/workspace/drive/api/guides/appdata), [Google Sign-In](https://developers.google.com/identity/sign-in/ios/sign-in), [AppAuth](https://github.com/openid/AppAuth-iOS).
