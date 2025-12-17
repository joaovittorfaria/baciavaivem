# RELATÓRIO PARCIAL
## Delimitação da Área de Estudo e Análise de Uso e Cobertura do Solo

### 1. Introdução
Este relatório parcial descreve e explica as etapas desenvolvidas no código apresentado, cujo objetivo é delimitar a Microbacia do Ribeirão Vai e Vem (município de Ipameri – GO) e analisar a dinâmica temporal do uso e cobertura do solo a partir de dados do MapBiomas, utilizando os ambientes R e Google Earth Engine (GEE).
O fluxo metodológico está organizado em três grandes etapas:
* **Etapa 1:** Delimitação da área de estudo em ambiente R (dados vetoriais);
* **Etapa 2:** Integração com o Google Earth Engine e obtenção dos dados MapBiomas;
* **Etapa 3:** Organização, análise estatística e visualização dos resultados.

## 2. Etapa 1 – Delimitação da Área de Estudo
### 2.1 Carregamento de pacotes
Nesta etapa são utilizados os pacotes:
* **sf:** manipulação de dados espaciais vetoriais;
* **dplyr:** manipulação e filtragem de dados tabulares;
* **mapview:** visualização interativa de dados espaciais.
O uso de `requireNamespace()` tem como objetivo verificar se os pacotes estão instalados antes de carregá-los, garantindo maior robustez ao script.
### 2.2 Leitura do shapefile
O comando `file.choose()` permite que o usuário selecione manualmente o shapefile contendo as bacias hidrográficas. Em seguida, a função `st_read()` importa o arquivo para o ambiente R, criando um objeto do tipo **sf**, que contém tanto os atributos quanto a geometria espacial.
### 2.3 Conferência dos atributos
A listagem das colunas do shapefile (`names(bacia_sf)`) é realizada para identificar os atributos disponíveis. Essa etapa é essencial para verificar qual campo contém o nome da bacia hidrográfica, que será utilizado no processo de filtragem.
### 2.4 Transformação do sistema de referência espacial (CRS)
Os dados são reprojetados para o sistema **SIRGAS 2000 (EPSG:4674)**, padrão oficial adotado no Brasil. Essa padronização é fundamental para garantir compatibilidade com bases cartográficas nacionais.
A função `mapview()` é utilizada para uma visualização inicial das bacias hidrográficas.
### 2.5 Filtragem da microbacia do Ribeirão Vai e Vem
Nesta etapa, o código verifica se existe uma coluna chamada `nome_bacia`. Caso exista, aplica-se um filtro textual (`grepl`) para selecionar apenas as feições cujo nome contenha a palavra "vai", identificando a microbacia de interesse.
Caso a coluna não exista, o script é interrompido com uma mensagem de erro, evitando resultados inconsistentes.
### 2.6 Dissolução da geometria
A função `st_union()` é utilizada para dissolver todas as feições selecionadas em uma única geometria. Esse procedimento garante que a microbacia seja representada como um único polígono contínuo, adequado para análises espaciais posteriores.
### 2.7 Preparação para o Google Earth Engine
Antes da integração com o GEE, a geometria passa por dois procedimentos:
* **Correção topológica:** `st_make_valid()` assegura que o polígono não possua erros geométricos;
* **Reprojeção para WGS84 (EPSG:4326):** sistema exigido pelo Google Earth Engine.
Uma nova visualização é realizada para conferência final.
### 2.8 Exportação do resultado
A microbacia delimitada é exportada no formato **GeoPackage (.gpkg)** para a pasta `data/`. Esse formato é recomendado por suportar múltiplas camadas, atributos complexos e maior integridade dos dados.

## 3. Etapa 2 – Integração com Google Earth Engine
### 3.1 Configuração do ambiente Python
Utiliza-se o pacote **reticulate** para definir explicitamente o ambiente Python associado ao Earth Engine. Essa etapa garante que o R utilize o Python correto, evitando conflitos de versões.
### 3.2 Inicialização do Earth Engine
O pacote **rgee** é carregado e a função `ee_Initialize()` autentica e inicializa o acesso ao Google Earth Engine. A verificação com uma `ImageCollection` confirma que a conexão foi estabelecida corretamente.
### 3.3 Conversão da microbacia para objeto ee
O arquivo GeoPackage exportado na Etapa 1 é novamente carregado, validado e convertido para um objeto do tipo **ee$FeatureCollection**, possibilitando seu uso direto nas operações do GEE.
### 3.4 Seleção dos dados MapBiomas
É acessado o **MapBiomas Coleção 10**, que contém mapas anuais de uso e cobertura do solo do Brasil. São selecionadas as bandas correspondentes aos anos de 1985 a 2024, e os dados são recortados (clip) à área da microbacia.

## 4. Etapa 3 – Análise Temporal do Uso e Cobertura do Solo
### 4.1 Leitura e organização dos dados
Os dados exportados do MapBiomas em formato CSV são importados e organizados. As colunas de interesse (ano, área, classe e nome) são padronizadas e agregadas por ano e classe.
### 4.2 Análise gráfica temporal
São gerados gráficos de linhas que representam a evolução temporal das classes de uso e cobertura do solo na microbacia, permitindo identificar tendências de expansão ou retração ao longo do período analisado.
### 4.3 Comparação entre anos-chave
Gráficos de barras são produzidos para anos específicos (1985, 2000, 2010 e 2023), facilitando a comparação visual entre períodos distintos da ocupação do solo.
### 4.4 Cálculo da variação total
É calculada a variação absoluta (hectares) e percentual de cada classe entre o primeiro e o último ano da série histórica, identificando os usos com maior transformação espacial.
### 4.5 Agrupamento temático das classes
As classes do MapBiomas são agrupadas em categorias mais amplas (Vegetação natural, Agropecuária, Área urbana, Corpos d’água e Outros). Essa simplificação permite uma interpretação mais clara das mudanças estruturais na paisagem.
Também são calculadas:
* a variação total por grupo;
* a taxa média anual de mudança (ha/ano e %/ano).
### 4.6 Exportação dos resultados
As tabelas finais e indicadores de variação são exportados em formato CSV para a pasta `resultados/`, possibilitando o uso em relatórios, artigos científicos ou outros softwares de análise.

## 5. Considerações finais
Este relatório parcial documenta de forma sistemática o processo de delimitação da microbacia do Ribeirão Vai e Vem e a análise temporal do uso e cobertura do solo. As etapas descritas asseguram rastreabilidade metodológica, integração entre R e Google Earth Engine e geração de resultados consistentes para análises ambientais e territoriais futuras.
