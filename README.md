# Plantão na Mão · iOS 1.3

Agenda nativa para iPhone/iPad, com suporte a iOS 17 ou superior e Liquid Glass nativo no iOS 26.

## Novidades 1.3

- Os três últimos plantões adicionados aparecem no topo do cadastro. Toque para copiar nome, horários, local, cor, valor e observações para um novo registro, com outro UUID. A data escolhida no calendário ou formulário é mantida; a previsão de pagamento é recalculada pelo padrão configurado, sem copiar o vencimento antigo.
- Deslize um plantão na agenda para editar ou excluir; a exclusão sempre pede confirmação.
- A agenda mostra o mês inteiro, do dia 1 ao último dia. Ao abrir o app, a lista começa no dia atual. Selecionar uma data rola a lista até ela, mas os dias anteriores continuam acessíveis. O calendário permanece fixo.
- Preço por plantão ou por hora. O cálculo por hora considera minutos e plantões noturnos, arredondando ao centavo. R$ 26,36/h das 07:00 às 19:00 = R$ 316,32.
- Valores aceitam vírgula ou ponto decimal e completam duas casas ao sair do campo. Um plantão salvo já entra na previsão financeira, sem chave manual de pagamento recebido.
- Financeiro por intervalo inclusivo de datas ou competências, ambos com dia, mês e ano, usando a data do plantão ou a previsão de pagamento. Sem previsão de pagamento, o registro continua disponível pelo filtro Plantão.
- INSS e imposto de renda opcionais, com percentuais manuais independentes sobre o bruto. Bruto, descontos e líquido são atualizados automaticamente. São estimativas: não aplicamos tabelas oficiais nem cálculo tributário progressivo.
- Painel mensal com plantões, horas, bruto, líquido estimado, gráfico dos últimos 12 meses e histórico mensal completo, incluindo meses sem movimento entre os registros.
- As 24 cores ficam no cadastro do plantão e nos aros; a aparência geral mantém a identidade jade, com opções clara, escura e automática.
- Widgets pequeno, médio e grande dedicados ao calendário, sem resumo ou mensagens no rodapé, com aros circulares nas cores dos plantões e aparência clara/escura. Dados são publicados em um arquivo atômico do App Group antes de recarregar a timeline; há diagnóstico e atualização manual em Ajustes. A extensão já é compilada e incluída no IPA. Ver [configuração dos widgets](WIDGETS_SETUP.md).

## Instalação e widgets

Execute `xcodegen generate`, abra o projeto e configure sua equipe de assinatura Apple. O App Group padrão é `group.com.plantaonamao.shared`, que precisa ser registrado e habilitado na mesma equipe para app e extensão. Leia [WIDGETS_SETUP.md](WIDGETS_SETUP.md). Sem assinatura compatível com App Groups, o app funciona, mas o widget não recebe os registros.

O iOS controla quando widgets são redesenhados. Solicitamos atualizações ao salvar, excluir, sincronizar e mudar a aparência, além de atualizar o dia pela timeline. Não há garantia de atualização contínua com o app fechado.

## Google e dados anteriores

Mantemos a chave local original e o formato de valores em centavos. Campos novos são opcionais na leitura dos registros antigos. A sincronização passa a usar schema 2, lendo o schema 1 anterior; outros aparelhos precisam atualizar para 1.3 para sincronizar sem descartar os campos de cálculo por hora. O Client ID público do projeto original continua incluído. A API Drive e a autorização OAuth precisam estar configuradas; siga [GOOGLE_SYNC_SETUP.md](GOOGLE_SYNC_SETUP.md).

Os plantões e os novos campos de preço/data de criação são sincronizados. Preferências de aparência e percentuais de simulação financeira continuam locais. Registros de recebimento das versões anteriores são preservados internamente; a interface 1.3 passa a mostrar previsões, sem exigir marcação manual.

## PDF

Preservamos PDF individual, escala e pagamentos. O relatório aberto pelo Financeiro usa o período selecionado e inclui bruto, INSS, imposto de renda e líquido estimados. Observações são opcionais. PDF é relatório, não backup restaurável.

## Compilação automática

Os workflows **Compilar Plantão na Mão iOS 1.3** e **Extrair projeto iOS 1.3 automaticamente** são acionados pela branch main e permitem execução manual. A geração do IPA Release é independente dos testes de interface para não bloquear o pacote quando os simuladores do GitHub estiverem indisponíveis. O empacotamento verifica que a extensão .appex está incluída.

Baixe os resultados em Artifacts. O IPA automático é **sem assinatura Apple**. Para manter seus dados, atualize a instalação anterior com o mesmo Bundle ID e assinatura compatível, sem desinstalar.

## Testes

`bash scripts/check-models.sh` valida valores, preço por hora, descontos, períodos, histórico mensal, migração e conciliação em dois fusos. Os testes iOS incluem PDFs, persistência, últimos três modelos e erros da sincronização. Os testes de interface verificam o dia atual na agenda, o calendário fixo, o acesso a Ajustes e o caminho selecionar dia 20 → reaproveitar preset → salvar → abrir o plantão no dia 20. As verificações de modelos cobrem datas exatas de competência e a leitura/regravação do arquivo compartilhado do widget.
