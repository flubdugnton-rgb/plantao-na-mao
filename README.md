# Plantão na Mão · iOS 1.0

Agenda nativa para iPhone e iPad, em português, com SwiftUI e iOS 17 ou superior. O nome exibido no aparelho é **Plantão na Mão**; o identificador do app continua sendo `com.plantaonamao.app`.

## O que está disponível

- Calendário mensal com navegação, botão Hoje e cores dos plantões.
- Cadastro, edição e exclusão de plantões, com local, horários e observações.
- Plantões que atravessam a meia-noite; horários iguais representam 24 horas.
- Doze cores para os plantões e para o tema do app; aparência clara, escura ou automática.
- Valores em reais, situação de recebimento e alertas de atraso na tela financeira.
- Pagamento sem previsão, por dia padrão do mesmo/próximo mês ou por data personalizada em cada plantão.
- Relatórios em PDF da escala, dos pagamentos e de um plantão individual; filtros por mês, período completo e situação do recebimento.
- Salvar PDF em Arquivos, compartilhar pelo menu do iOS ou imprimir. As observações podem ser omitidas.
- PDFs A4 com texto selecionável e paginação automática, incluindo observações extensas.
- Locais agrupados a partir dos plantões e dados disponíveis sem internet.

## Pagamentos

Em **Ajustes**, escolha o dia padrão e se o pagamento ocorre no mês seguinte. No cadastro de cada plantão, escolha **Data personalizada** para definir qualquer data. O padrão é convertido em data ao salvar; mudar os ajustes não altera previsões já cadastradas. Dias 29–31 são limitados ao último dia de meses mais curtos.

O resumo da **Escala** usa o mês do plantão. O **Financeiro** usa o mês da previsão de pagamento. Valores sem previsão aparecem em uma seção própria ou ao selecionar todos os períodos. Deslize um pagamento para a direita para marcar como recebido ou pendente.

## Abrir e instalar no iPhone

1. Instale o Xcode e o XcodeGen (`brew install xcodegen`) em um Mac.
2. Na pasta do projeto, execute `xcodegen generate`.
3. Abra `PlantaoNaMao.xcodeproj` e selecione o esquema `PlantaoNaMao`.
4. Em **Signing & Capabilities**, selecione sua equipe Apple. Se necessário, ajuste o Bundle Identifier.
5. Selecione o iPhone ou simulador e execute com **Run**.

Para manter os dados da instalação anterior, use o mesmo Bundle Identifier e uma assinatura compatível, atualizando o app sem desinstalá-lo.

## Compilação automática no GitHub

Em **Actions**, há dois workflows que executam automaticamente ao atualizar os arquivos na branch `main`, além de permitir **Run workflow**:

### Compilar Plantão na Mão iOS 1.0

Valida as regras de cálculo, testa migração e PDFs no simulador, compila o app para iPhone/iPad e disponibiliza os arquivos em **Artifacts**:

- `PlantaoNaMao-1.0-sem-assinatura.ipa`
- `PlantaoNaMao-Xcode.zip`
- resultados dos testes

**O IPA automático não está assinado.** Ele exige assinatura Apple e provisionamento antes da instalação. Não é um link de instalação direta nem um pacote TestFlight. Para TestFlight/App Store, use o projeto Xcode, configure sua equipe e faça **Product > Archive > Distribute App**.

### Extrair projeto iOS 1.0 automaticamente

Gera o projeto Xcode e disponibiliza um ZIP completo com os fontes, testes, configurações e workflows, pronto para abrir no Mac. Não tenta reconstruir código-fonte a partir de um IPA: usa os fontes recuperados do histórico deste repositório e atualizados nesta edição.

## Dados e compatibilidade

Os plantões permanecem em `UserDefaults`, sob a chave original `plantao-na-mao.shifts`. Registros da versão anterior são lidos sem exigir campos financeiros. Em caso de falha na leitura, os bytes originais são preservados e as alterações são bloqueadas para evitar sobrescrita. Não há login, sincronização em nuvem ou integração OAuth nesta versão. Desinstalar o app pode apagar os registros locais. PDF é relatório, não backup restaurável.

## Validação

Execute `bash scripts/check-models.sh` para validar valores em reais, datas de pagamento, virada de ano, ano bissexto, turnos noturnos, migração e filtros em dois fusos horários.

Os testes iOS `PlantaoNaMaoTests` verificam persistência, proteção dos dados ilegíveis e PDFs com múltiplas páginas, texto final preservado e exclusão opcional das observações. Eles são executados no workflow de compilação.

## Origem

Esta edição recupera o protótipo SwiftUI do arquivo `PlantaoNaMao-source.zip` presente no commit `3235ce4c832b0eb28d66b6e9cfdb4d5bbcce4290` deste repositório. Nenhum binário de terceiros, segredo ou recurso de assinatura foi incorporado.
