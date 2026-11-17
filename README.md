# Plantão na Mão · iOS 1.1

Agenda nativa para iPhone e iPad, em português, com SwiftUI e iOS 17 ou superior. Bundle ID preservado: `com.plantaonamao.app`.

## Novidades da versão 1.1

- Liquid Glass nativo nos controles e na navegação no iOS 26, compilado com Xcode 26. Em iOS 17–18, os controles usam materiais compatíveis; a opção de acessibilidade Reduzir Transparência é respeitada.
- Nome do aplicativo no topo e mês atual em tamanho grande logo abaixo, com navegação entre meses.
- Calendário fixo: apenas a lista de plantões abaixo dele rola, incluindo os próximos dias do mês.
- Aros coloridos ao redor dos dias com plantões; quando há cores diferentes no mesmo dia, o aro é dividido nas respectivas cores.
- Remoção do cartão e da frase “Tudo sob controle. Um plantão por vez.”.
- 24 cores para o tema e para os plantões, mantendo as cores dos registros da versão anterior.
- Conta Google e sincronização automática opcional por Google Drive, com formato de dados reutilizável na futura versão para Mac.
- Versão do app atualizada para 1.1, build 3, e workflows de geração do projeto e compilação atualizados.

## Recursos mantidos

Calendário mensal, cadastro/edição/exclusão de plantões, locais, notas, horários noturnos, valores em reais e marcação de recebimento. PDF da escala, dos pagamentos e de um plantão individual, com filtros, observações opcionais, texto selecionável e paginação automática. Compartilhamento, impressão e salvamento em Arquivos.

Em **Ajustes**, configure o dia padrão de pagamento do mesmo mês ou do mês seguinte. Em cada plantão, escolha uma **Data personalizada**, o dia padrão ou nenhuma previsão. Mudar os ajustes não altera as datas já salvas. Em meses curtos, dias 29–31 são limitados ao último dia do mês.

O resumo da escala usa o mês do plantão; o financeiro usa o mês da previsão de pagamento.

## Google e futura versão para Mac

Abra **Ajustes > Conta Google** e conecte sua conta. A sincronização tenta executar ao abrir, depois de alterações e periodicamente enquanto o aplicativo estiver ativo. Sem conexão, os registros permanecem no aparelho.

**A integração exige que a API Google Drive e o consentimento OAuth estejam configurados no projeto Google Cloud do proprietário.** O Client ID público do projeto original e o retorno OAuth foram incluídos. Leia [GOOGLE_SYNC_SETUP.md](GOOGLE_SYNC_SETUP.md) para ativar, trocar as credenciais e testar em aparelhos reais.

A entrega 1.1 é para iPhone/iPad; o futuro aplicativo Mac poderá reutilizar os modelos, o formato de sincronização e o cliente Drive. O iOS pode suspender o aplicativo em segundo plano, portanto não há promessa de sincronização contínua com o app fechado.

## Abrir no Xcode

1. Instale Xcode 26 e XcodeGen em um Mac.
2. Execute `xcodegen generate` na pasta do projeto.
3. Abra `PlantaoNaMao.xcodeproj`, selecione o esquema `PlantaoNaMao` e aguarde a resolução do SDK oficial Google Sign-In via Swift Package Manager.
4. Configure **Signing & Capabilities**, selecione seu iPhone ou simulador e use **Run**.

Para manter os dados da instalação 1.0, atualize o aplicativo sem desinstalar, com o mesmo Bundle ID e uma assinatura compatível. Se alterar o Bundle ID ao assinar, configure também as credenciais OAuth correspondentes.

## Workflows automáticos

Os dois workflows executam ao atualizar os arquivos na branch `main` e também permitem **Run workflow**:

- **Compilar Plantão na Mão iOS 1.1:** seleciona Xcode 26, testa regras de negócio, sincronização e PDFs, valida no simulador que o calendário fica fixo durante a rolagem, compila o app e disponibiliza IPA, projeto Xcode, resultados de testes e capturas de tela em **Artifacts**.
- **Extrair projeto iOS 1.1 automaticamente:** gera e empacota o projeto Xcode completo com fontes, testes, workflows e orientações Google.

O IPA automático é **sem assinatura**. Para instalar, use uma assinatura Apple e provisionamento válidos. Para TestFlight/App Store, configure sua equipe no Xcode e use **Product > Archive > Distribute App**.

## Dados e migração

A chave original `plantao-na-mao.shifts` é preservada. A versão 1.1 também grava o estado de sincronização com versões dos registros e marcadores de exclusão. Registros da versão 1.0 são migrados sem exigir campos novos. Dados ilegíveis são preservados e bloqueiam alterações para evitar sobrescrita.

Cada dispositivo atualiza somente seu arquivo privado no Drive. Em conflito de edição do mesmo plantão, vence a alteração mais recente; exclusões persistidas impedem o retorno de cópias antigas. A conta vinculada é conferida antes de enviar dados. Desconectar mantém os registros locais. PDF é relatório, não backup restaurável.

## Validação

Execute `bash scripts/check-models.sh` para verificar valores, datas, turnos noturnos, migração, filtros e conciliação entre dispositivos em dois fusos horários. Os testes iOS cobrem PDFs extensos, persistência, exclusões, erros de rede/permissão e layout fixo do calendário.

A autenticação Google e a sincronização entre aparelhos reais exigem credenciais e consentimento do usuário; os testes HTTP usam respostas simuladas.

## Origem

A edição 1.0 recuperou o protótipo SwiftUI do arquivo `PlantaoNaMao-source.zip` no commit `3235ce4c832b0eb28d66b6e9cfdb4d5bbcce4290` deste repositório. A edição 1.1 atualiza esse código, sem incorporar binários ou mecanismos de desbloqueio do aplicativo usado como referência visual.
