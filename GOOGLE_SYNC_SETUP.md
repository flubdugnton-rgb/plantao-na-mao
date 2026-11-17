# Configurar a sincronização Google · versão 1.2

O código usa o SDK oficial **Google Sign-In 10.1.0**, com OAuth e tokens gerenciados pelo SDK no Keychain. Os dados ficam exclusivamente no espaço privado `appDataFolder` do Google Drive, com o escopo `https://www.googleapis.com/auth/drive.appdata`. Não pede acesso aos demais arquivos do Drive.

## Configuração já incluída

O projeto reaproveita o Client ID público encontrado em `GoogleSignInConfig.swift` no projeto original:

```
240965240632-fd5s8htiparn8kk84rpctc1ggrfrur2g.apps.googleusercontent.com
```

O Bundle ID continua sendo `com.plantaonamao.app`. O esquema de retorno OAuth já está configurado em `project.yml`, e o XcodeGen gera o `Info.plist` correspondente. Um Client ID identifica o app; ele não é um segredo. Nenhum client secret deve ser colocado no app ou no repositório.

## Ativação no Google Cloud

1. Acesse o projeto Google Cloud que possui esse Client ID. Se não tiver acesso, crie seu próprio projeto e um cliente OAuth do tipo **iOS**, usando o Bundle ID do aplicativo.
2. Ative a **Google Drive API** nesse mesmo projeto.
3. Configure a tela de consentimento OAuth do app e adicione o escopo `drive.appdata`.
4. Se o projeto estiver em modo de teste, cadastre as contas que vão experimentar a sincronização como usuários de teste. Em produção, siga as exigências de publicação exibidas pelo Google.
5. Confira que o cliente OAuth é de iOS e corresponde ao Bundle ID e, quando exigido pelo Google, à equipe de assinatura. Se trocar o Bundle ID para assinar o IPA, ajuste também o cliente OAuth.
6. Caso use outro Client ID, altere **GIDClientID** e **CFBundleURLSchemes** em `project.yml`. O esquema de URL é o Client ID invertido, sem o sufixo `.apps.googleusercontent.com` e com o prefixo `com.googleusercontent.apps.`.
7. Gere e assine uma nova compilação, abra **Ajustes > Conta Google** e toque em **Sign in with Google**. Autorize a pasta privada do aplicativo.

Não é necessário conectar a conta Google ao ChatGPT para que o login do app funcione. A autenticação ocorre diretamente no iPhone.

## Funcionamento

- A sincronização é opcional; o app continua funcionando offline.
- Depois de conectar, o app tenta sincronizar ao abrir, cerca de dois segundos após alterações e a cada 30 segundos enquanto estiver ativo. O botão **Sincronizar agora** permite antecipar uma tentativa.
- O iOS pode suspender aplicativos fechados ou em segundo plano. A versão 1.2 não promete sincronização contínua com o aplicativo fechado; ela retoma automaticamente ao voltar.
- Cada instalação grava um arquivo próprio, identificado por um UUID do dispositivo. A sincronização lê os arquivos de todos os dispositivos da mesma conta, mescla os registros e atualiza apenas o arquivo da instalação atual.
- Registros são conciliados por UUID, data da alteração e desempate determinístico. Em edições simultâneas do mesmo plantão, prevalece a alteração mais recente; mantenha os relógios dos aparelhos corretos.
- Exclusões também são sincronizadas e preservadas como marcadores, para que uma cópia antiga não recadastre um plantão apagado.
- Falhas de rede, permissão, leitura ou incompatibilidade de versão interrompem a operação sem apagar os registros locais.
- Alterações feitas durante uma tentativa são preservadas e enviadas na próxima. Os tokens não são incluídos nos arquivos de plantões.
- O aparelho guarda o identificador da conta vinculada aos registros. Para evitar misturar dados, não envia silenciosamente o mesmo banco de dados para uma conta diferente ao reconectar.
- Desconectar remove a sessão Google, mas mantém os plantões locais e os arquivos já gravados no Drive. O usuário pode gerenciar a autorização do aplicativo nas configurações da própria conta Google.
- Cores dos plantões, observações, horários, valores, previsões e situação dos pagamentos são sincronizados. Tema, aparência e dia padrão de pagamento são preferências locais de cada aparelho.

## Preparação para o futuro app Mac

`Models.swift`, `SyncModels.swift` e `GoogleDriveSync.swift` usam Foundation e podem ser reutilizados em um target macOS. Crie as credenciais macOS no **mesmo projeto Google Cloud**, use o mesmo escopo e formato JSON e conecte a mesma conta Google. A interface e o apresentador de login do Mac precisam de uma implementação própria; a versão 1.2 entregue aqui continua sendo o app de iPhone/iPad.

## Validação que exige uma conta real

Os testes automatizados cobrem as regras de conciliação, exclusões, migração e chamadas HTTP simuladas. A ativação da API Drive, o consentimento OAuth e a sincronização entre dois aparelhos reais precisam ser confirmados com a conta Google e as credenciais do proprietário. Não é possível validar essas etapas apenas com um IPA sem assinatura.

Referências oficiais:

- https://developers.google.com/identity/sign-in/ios/sign-in
- https://developers.google.com/identity/sign-in/ios/api-access
- https://developers.google.com/workspace/drive/api/guides/appdata

Na versão 1.2, a sincronização grava schema 2 e migra snapshots schema 1. Atualize os outros aparelhos antes de sincronizar; o cálculo por hora e a data de criação fazem parte dos registros sincronizados.
