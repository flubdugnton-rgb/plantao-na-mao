## Versão macOS

A extensão nativa do Mac usa o mesmo calendário e formato de dados, com targets **PlantaoNaMaoMac** e **PlantaoNaMaoMacWidgets**. A sincronização pelo Google não exige Apple Developer; a autorização para compartilhar dados localmente com o widget exige uma assinatura Apple compatível para app e extensão. O download ad hoc permite testar o app, mas não comprova acesso do widget ao App Group. Leia [MACOS_SETUP.md](MACOS_SETUP.md).

# Widgets · Plantão na Mão 1.4

O widget usa somente o calendário com aros, com tamanhos pequeno, médio e grande e temas claro/escuro. O iOS controla o momento das atualizações. Uma extensão compilada e presente no IPA não garante acesso aos dados: isso depende das permissões na assinatura instalada.

## KSign sem App Groups

A versão 1.4 oferece uma alternativa pelo Keychain (Chaves). O perfil mostrado nesta conversa não declara `com.apple.security.application-groups`, mas declara `keychain-access-groups`. O código do KSign/Zsign consultado utiliza as permissões do perfil ao reassinar os executáveis. A alternativa pode funcionar se app e extensão receberem um grupo de Chaves em comum; a confirmação de leitura é a verificação no aparelho, não apenas a presença de uma chave no perfil.

1. Importe e assine o IPA 1.4 no KSign, usando o mesmo certificado para o app e a extensão. Preserve `PlugIns/PlantaoNaMaoWidgets.appex`.
2. Para atualizar sem apagar os registros, mantenha os identificadores usados na instalação anterior e não desinstale o app.
3. Abra o Plantão na Mão e vá a **Ajustes > Widgets > Atualizar widget agora**.
4. Volte à tela inicial. Após atualizar da 1.3, remover e adicionar somente o widget pode limpar uma apresentação antiga. Não remova o aplicativo.
5. Abra Ajustes novamente para conferir o diagnóstico. **“O widget confirmou a leitura…”** significa que a extensão conseguiu decodificar os dados. **“Calendário gravado… aguardando…”** significa apenas que o app gravou: não confirma acesso da extensão. **“A assinatura não permitiu…”** indica falha de gravação e mostra o código das Chaves.

O grupo `keychain-access-groups` no perfil é uma autorização para a assinatura, não prova dos grupos efetivamente assinados nos dois executáveis. Se não houver confirmação, será necessário um grupo de Chaves comum ou App Group autorizado em ambos; não basta acrescentar uma permissão sem autorização a um plist.

A alternativa envia exclusivamente datas e cores do mês anterior, atual e seguinte, além da aparência e da data de atualização. Não envia nomes, locais, valores, observações, identificadores de plantão ou credenciais. Os registros completos continuam no armazenamento local original. Abra o app após a virada do mês para renovar a janela enviada às Chaves. A leitura não mostra janelas de autenticação.

## Assinatura pelo Xcode

1. Execute `xcodegen generate` e abra `PlantaoNaMao.xcodeproj`.
2. Selecione a mesma equipe Apple nos targets **PlantaoNaMao** e **PlantaoNaMaoWidgets**.
3. O App Group padrão é `group.com.plantaonamao.shared`: registre-o e habilite-o nos dois perfis. Se sua equipe exigir outro grupo, altere `APP_GROUP_IDENTIFIER` em `project.yml` antes de gerar o projeto.
4. Os dois targets também declaram Keychain Sharing: `$(AppIdentifierPrefix)com.plantaonamao.widget`. O grupo privado de cada target permanece primeiro, para preservar a área padrão usada pelo login Google. O calendário seleciona explicitamente o grupo compartilhado quando autorizado; se um assinador substituir as permissões, tenta os grupos concedidos na assinatura. O prefixo deve ser expandido pela assinatura da sua equipe. Não há Team ID fixo no aplicativo.
5. Bundle IDs padrão: `com.plantaonamao.app` e `com.plantaonamao.app.widgets`. Configure os perfis correspondentes e assine os dois targets juntos.

O IPA automático é **sem assinatura**. A compilação não registra nem concede permissões na conta Apple. Certificados, chaves privadas e senhas não precisam ser enviados para usar os diagnósticos do aplicativo.

## Atualizações

O app solicita recarga ao salvar, excluir, sincronizar, trocar a aparência, abrir e ir para segundo plano. A extensão escolhe a fonte mais recente entre App Group e Chaves. Apenas a extensão escreve a confirmação de leitura; o app nunca confirma a própria gravação. A confirmação usa um SHA-256 das datas, cores e aparência; não registra dados financeiros.

A timeline antecipa sete viradas de dia/mês e solicita novas leituras periodicamente. O iOS pode adiar a atualização e não oferece execução contínua do widget com o app fechado.

Referências:
- https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps
- https://developer.apple.com/documentation/xcode/configuring-app-groups
- https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date
- https://github.com/Nyasami/Ksign/blob/main/Ksign/Utilities/Handlers/ZsignHandler.swift
- https://github.com/claration/zsign/blob/6ffe703df73ef9069adacdbb19d571f11a69a801/src/openssl.cpp
- https://github.com/claration/zsign/blob/6ffe703df73ef9069adacdbb19d571f11a69a801/src/archo.cpp
