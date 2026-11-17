# Widgets · Plantão na Mão 1.2

O projeto inclui uma extensão WidgetKit, embutida no aplicativo, com tamanhos pequeno, médio e grande. Os três mostram o calendário mensal com aros nas cores dos plantões; médio e grande também mostram próximos plantões e informações do mês. A aparência segue a escolha clara, escura ou automática do app.

## Assinar e habilitar o compartilhamento

1. Gere o projeto com `xcodegen generate` e abra `PlantaoNaMao.xcodeproj`.
2. Selecione a mesma equipe Apple em **Signing & Capabilities** dos targets **PlantaoNaMao** e **PlantaoNaMaoWidgets**.
3. Cadastre e habilite o mesmo App Group para os dois identificadores no Apple Developer: `group.com.plantaonamao.shared`.
4. Se sua equipe exigir outro identificador de grupo, altere `APP_GROUP_IDENTIFIER` em `project.yml`, gere o projeto novamente e habilite esse grupo nos dois targets. O aplicativo e a extensão leem o identificador dos seus respectivos Info.plist.
5. Os Bundle IDs padrão são `com.plantaonamao.app` e `com.plantaonamao.app.widgets`. Perfis de provisionamento precisam contemplar os identificadores e o App Group escolhidos.
6. Assine app e extensão juntos. Ao usar um assinador de IPA, preserve a pasta `PlugIns` e configure os direitos e perfis do App Group para ambos. Uma assinatura sem App Groups não permite que o widget leia os dados do app.

O IPA automático é sem assinatura. Compilar a extensão não cria nem autoriza o App Group na conta Apple. O aplicativo avisa em Ajustes se o compartilhamento não estiver disponível na assinatura instalada.

## Adicionar à tela inicial

Após instalar e abrir o aplicativo, mantenha pressionada a tela inicial do iPhone, escolha **Editar > Adicionar Widget**, procure **Plantão na Mão** e selecione o tamanho. Salve um plantão para solicitar a primeira atualização. Tocar em um dia no widget abre essa data no app; no tamanho pequeno, o iOS pode abrir a visão geral do widget.

## Atualização

O app grava os dados no contêiner compartilhado e solicita uma atualização ao salvar, excluir, sincronizar, trocar a aparência e ir para segundo plano. A extensão publica uma timeline com a mudança do dia e solicita novas timelines periodicamente.

O iOS controla o orçamento e o momento de atualização dos widgets. A versão 1.2 solicita atualização imediatamente após alterações, mas não promete atualização contínua em tempo real com o app fechado. Sincronização Google em segundo plano também depende do tempo de execução concedido ao aplicativo.

Referência: https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date
