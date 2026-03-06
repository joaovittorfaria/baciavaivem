#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Projeto de Pesquisa: PI05919-2025 - DIAGNÓSTICO DO USO E OCUPAÇÃO DO SOLO NA ÁREA DO ALTO CURSO DA MICROBACIA HIDROGRÁFICA DO RIBEIRÃO VAI-E-VEM NO MUNICÍPIO DE IPAMERI (GO)
# Orientador:	RAFAEL DE AVILA RODRIGUES ( Docente )
# Co-Orientador:	ANTOVER PANAZZOLO SARMENTO ( Docente )
# Centro:	UNIVERSIDADE FEDERAL DE CATALÃO
# Departamento:	INSTITUTO DE GEOGRAFIA
# Discente:	202301291 - JOAO VITTOR DE FARIA PEREIRA
# Objetivo: Criar um fluxo automatizado para a extração, processamento e análise de dados de uso e cobertura do solo na microbacia do Ribeirão Vai e Vem (Ipameri-GO), utilizando apenas a linguagem R e ferramentas de código aberto.
  
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Etapa 1: Delimitação da Área de Estudo

# Utilizar dados vetoriais da bacia hidrográfica obtidos do Instituto Brasileiro de Geografia e Estatística (IBGE) ou da Agência Nacional de Águas (ANA).
# Aplicar funções dos pacotes sf e terra para recortar a área de interesse (Ribeirão Vai e Vem – GO).
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  
# Dados Utilizados para delmitação da primeira etapa:
# Base Hidrográfica Ottocodificada da Bacia do Rio Paranaíba - Agência Nacional de Águas e Saneamento Básico (ANA) - https://metadados.snirh.gov.br/geonetwork/srv/por/catalog.search#/metadata/09436656-f4cf-4793-b169-33700b2d40ee
# Áreas de Contribuição Hidrográfica (shp) - https://metadados.snirh.gov.br/files/09436656-f4cf-4793-b169-33700b2d40ee/GEOFT_BHO_AREACONTRIBUICAO.zip
# Trechos de Drenagem (shp) - https://metadados.snirh.gov.br/geonetwork/srv/api/records/09436656-f4cf-4793-b169-33700b2d40ee/attachments/geoft_bho_trecho_drenagem.zip
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# ETAPA 1.1) CARREGAR PACOTES
# ---------------------------

# =========================================================
# ETAPA 1 — DELIMITAÇÃO DA MICROBACIA CORRETA (BHO)
# =========================================================

library(sf)
library(dplyr)
library(mapview)

sf_use_s2(FALSE)

# ---------------------------------------------------------
# 1.1 CARREGAR DADOS
# ---------------------------------------------------------

bacias <- st_read("C:/Users/João Vittor/Desktop/hidro/GEOFT_BHO_AREACONTRIBUICAO.shp")

drenagem <- st_read("C:/Users/João Vittor/Desktop/drenagem/geoft_bho_trecho_drenagem.shp")

# Garantir mesmo CRS
drenagem <- st_transform(drenagem, st_crs(bacias))

# Corrigir geometrias
bacias <- st_make_valid(bacias)
drenagem <- st_make_valid(drenagem)

# ---------------------------------------------------------
# 1.2 CRIAR PONTO DE EXUTÓRIO (Captação Ipameri)
# ---------------------------------------------------------

ponto_exutorio <- st_sfc(
  st_point(c(-48.159, -17.722)),  # Coordenadas
  crs = 4674
)

ponto_exutorio <- st_as_sf(data.frame(id = 1, geometry = ponto_exutorio))

# ---------------------------------------------------------
# 1.3 IDENTIFICAR TRECHO DE RIO MAIS PRÓXIMO
# ---------------------------------------------------------

dist <- st_distance(ponto_exutorio, drenagem)

trecho_id <- which.min(dist)

trecho_principal <- drenagem[trecho_id, ]

# Ver código completo da microbacia
print(trecho_principal$COBACIA)

# ---------------------------------------------------------
# 1.4 SELECIONAR A MICROBACIA CORRETA (SEM SUBSTR)
# ---------------------------------------------------------

codigo_bacia <- trecho_principal$COBACIA  # código completo

bacia_micro <- bacias[
  bacias$COBACIA == codigo_bacia,
]

# Garantir polígono único
bacia_micro <- st_union(bacia_micro)

bacia_micro <- st_as_sf(
  data.frame(id = 1, geometry = bacia_micro)
)

# ---------------------------------------------------------
# 1.5 RECORTAR DRENAGEM SOMENTE NA MICROBACIA
# ---------------------------------------------------------

drenagem_micro <- st_intersection(drenagem, bacia_micro)

# ---------------------------------------------------------
# 1.6 CALCULAR ÁREA DA MICROBACIA
# ---------------------------------------------------------

bacia_utm <- st_transform(bacia_micro, 31983)

area_km2 <- as.numeric(st_area(bacia_utm)) / 1000000

cat("Área da microbacia (km²):", area_km2, "\n")

# ---------------------------------------------------------
# 1.7 VISUALIZAÇÃO FINAL
# ---------------------------------------------------------

mapview(bacia_micro,
        col.regions = "lightgreen",
        alpha.regions = 0.4,
        layer.name = "Microbacia Correta") +
  
  mapview(drenagem_micro,
          color = "blue",
          lwd = 2,
          layer.name = "Drenagem") +
  
  mapview(ponto_exutorio,
          col.regions = "red",
          cex = 6,
          layer.name = "Exutório")

# ---------------------------------------------------------
# 1.8 EXPORTAR MICROBACIA CORRETA
# ---------------------------------------------------------

st_write(
  bacia_micro,
  "C:/Users/João Vittor/Desktop/trabalho/microbacia_vai_e_vem_alto_curso.gpkg",
  delete_dsn = TRUE
)


#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Etapa 2: Extração de Dados de Uso do Solo

# Usar o pacote rgee para conectar-se ao Google Earth Engine e extrair as imagens da Coleção 9 do MapBiomas (MapBiomas Brasil, 2024).
# Selecionar bandas correspondentes aos anos de 1985 a 2023.
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Antes de Instalar o Phyton, criar uma conta no Google Earth, criar um projeto e valide o projeto.
# Para Instalar o phyton, e poder utilizar o EARTH ENGINE no R-Studio usaremos o progama miniconda https://www.anaconda.com/docs/getting-started/miniconda/main
# Depois de Instalar o Miniconda abra o Anaconda Prompt como Administrador, rode o comando:
# conda create -n rgee_py python=3.9
# Instale todos os pacotes que foram requeridos no Prompt.Após isso execute todos os comandos para instalação dos API:
# activate rgee_py
# pip install google-api-python-client
# pip install earthengine-api
# pip install numpy
# exit ()
# Para achar o caminho python execute:
# conda env list
# Agora no R-studio rode somente a linha:

py_config()

# Copie o Caminho python, exemplo : python: C:/ProgramData/miniconda3/envs/rgee_py/python.exe
# Cole o diretório na linha posterior #Definir Python Antes do rgee entre as aspas.
# Caso estiver dando erro na hora de gerar o token do Google Earth, limpe as credenciais com as linhas a seguir , apenas tire a # rode e reinicie. 

#library(rgee)

#ee_clean_user_credentials()
#ee_Initialize()


# ETAPA 2.1) INSTALAÇÃO DE PACOTES 
# --------------------------------
if (!requireNamespace("reticulate", quietly = TRUE)) install.packages("reticulate")
if (!requireNamespace("rgee", quietly = TRUE)) install.packages("rgee")
if (!requireNamespace("sf", quietly = TRUE)) install.packages("sf")
if (!requireNamespace("geojsonio", quietly = TRUE)) install.packages("geojsonio")


# ETAPA 2.2) CARREGAR PACOTES
# ---------------------------
library(reticulate)

# Definir Python ANTES do rgee COLE O DIRETÓRIO DITO NA LINHA 163.
use_python(
  "C:/ProgramData/miniconda3/envs/rgee_py/python.exe",
  required = TRUE
)

library(rgee)
library(sf)
library(geojsonio)


# ETAPA 2.3 INICIALIZAR EARTH ENGINE 
# ----------------------------------
ee_Initialize(drive = TRUE)
ee <- rgee::ee


# ETAPA 2.4 CARREGAR MICROBACIA
# -----------------------------

# Verificar se o arquivo existe
# Substitua o Diretório do arquivo gerado da etapa 1 aqui, nossa area delimitada na etapa 1.
print(file.exists("C:/Users/João Vittor/Desktop/trabalho/microbacia_ribeirao_vai_e_vem.gpkg"))

# Substitua o Diretório do arquivo gerado da etapa 1 aqui, nossa area delimitada na etapa 1.
microbacia_sf <- st_read(
  "C:/Users/João Vittor/Desktop/trabalho/microbacia_vai_e_vem_alto_curso.gpkg",
  quiet = TRUE
)

microbacia_sf <- microbacia_sf |>
  st_make_valid() |>
  st_transform(4326)

microbacia_ee <- sf_as_ee(microbacia_sf)


# ETAPA 2.4) MAPBIOMAS COLEÇÃO 10
# -------------------------------

# MAPBIOMAS COLEÇÃO 10 (1985–2023)
mapbiomas10 <- ee$Image(
  "projects/mapbiomas-public/assets/brazil/lulc/collection10/mapbiomas_brazil_collection10_coverage_v2"
)

anos <- 1985:2023
bandas <- paste0("classification_", anos)

mapbiomas10_clip <- mapbiomas10$
  select(bandas)$
  clip(microbacia_ee)

mapbiomas10_clip$bandNames()$getInfo()

#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#Etapa 3: Processamento e Análise Espacial

# Recortar os dados do MapBiomas usando a geometria da microbacia.
# Classificar os valores de pixel conforme legenda oficial do MapBiomas.
# Calcular proporção de cada classe de uso do solo por ano.
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# =========================================================
# ETAPA 3 — USO E COBERTURA DO SOLO (MAPBIOMAS 2023)
# =========================================================

library(terra)
library(sf)
library(ggplot2)
library(dplyr)

# ---------------------------------------------------------
# 3.1 BAIXAR RASTER DO EARTH ENGINE
# ---------------------------------------------------------

mapbiomas_raster <- ee_as_rast(
  image = mapbiomas10_clip,
  region = microbacia_ee$geometry(),
  scale = 30
)

# selecionar banda 2023
img_2023_r <- mapbiomas_raster[["classification_2023"]]

# remover pixels 0
img_2023_r[img_2023_r == 0] <- NA

# ---------------------------------------------------------
# 3.2 CONVERTER PARA DATAFRAME (ggplot)
# ---------------------------------------------------------

img_2023_df <- as.data.frame(
  img_2023_r,
  xy = TRUE,
  na.rm = TRUE
)

colnames(img_2023_df) <- c("x", "y", "classe")

# ---------------------------------------------------------
# 3.3 SELECIONAR CLASSES RELEVANTES
# ---------------------------------------------------------

img_2023_df$classe <- factor(
  img_2023_df$classe,
  levels = c(3,4,9,11,12,15,21,24,33,39,41),
  labels = c(
    "Formação Florestal",
    "Formação Savânica",
    "Floresta Plantada",
    "Área Úmida Natural",
    "Formação Natural não Florestal",
    "Pastagem",
    "Agricultura",
    "Área Urbana",
    "Corpos d'Água",
    "Soja",
    "Outras Lavouras Temporárias"
  )
)

# ---------------------------------------------------------
# 3.4 CORES OFICIAIS MAPBIOMAS
# ---------------------------------------------------------

cores_mapbiomas <- c(
  "Formação Florestal" = "#006400",
  "Formação Savânica" = "#00FF00",
  "Floresta Plantada" = "#4CAF50",
  "Área Úmida Natural" = "#B8AF4F",
  "Formação Natural não Florestal" = "#F1C232",
  "Pastagem" = "#FF6D4C",
  "Agricultura" = "#FF8C00",
  "Área Urbana" = "#E06666",
  "Corpos d'Água" = "#6FA8DC",
  "Soja" = "#F4A460",
  "Outras Lavouras Temporárias" = "#FFA500"
)

# ---------------------------------------------------------
# 3.5 CARREGAR RIO DA MICROBACIA
# ---------------------------------------------------------

drenagem_micro <- st_read(
  "C:/Users/João Vittor/Desktop/drenagem/geoft_bho_trecho_drenagem.shp",
  quiet = TRUE
)

drenagem_micro <- st_transform(drenagem_micro, 4326)

drenagem_micro <- st_intersection(
  drenagem_micro,
  microbacia_sf
)

# ---------------------------------------------------------
# 3.6 MAPA FINAL
# ---------------------------------------------------------

ggplot() +
  
  geom_raster(
    data = img_2023_df,
    aes(x = x, y = y, fill = classe)
  ) +
  
  geom_sf(
    data = microbacia_sf,
    fill = NA,
    color = "black",
    linewidth = 0.6
  ) +
  
  geom_sf(
    data = drenagem_micro,
    color = "blue",
    linewidth = 0.8
  ) +
  
  scale_fill_manual(
    values = cores_mapbiomas,
    na.value = "transparent",
    name = "Uso e Cobertura do Solo"
  ) +
  
  coord_sf() +
  
  labs(
    title = "Uso e Cobertura do Solo (MapBiomas 2023)",
    subtitle = "Microbacia Ribeirão Vai-e-Vem — Ipameri (GO)",
    x = "Longitude",
    y = "Latitude"
  ) +
  
  theme_minimal(base_size = 13) +
  
  theme(
    legend.position = "right",
    plot.title = element_text(face = "bold", size = 16),
    plot.subtitle = element_text(size = 12)
  )


library(tidyverse)

# =========================
# 1. Ler CSV
# =========================
caminho_csv <- file.choose()

mb_raw <- read_csv(caminho_csv)

# =========================
# 2. Organizar dados
# =========================
mb_tab <- mb_raw %>%
  select(ano, area_ha, nome) %>%
  mutate(
    ano = as.integer(ano),
    area_ha = as.numeric(area_ha)
  ) %>%
  group_by(ano, nome) %>%
  summarise(area_ha = sum(area_ha), .groups = "drop")

# =========================
# 3. GRÁFICO COM TODAS AS CLASSES
# =========================
ggplot(mb_tab, aes(x = ano, y = area_ha, color = nome)) +
  geom_line(linewidth = 1.1) +
  labs(
    title = "Mudança do uso e cobertura do solo",
    subtitle = "Microbacia do Ribeirão Vai-e-Vem — Ipameri (GO)",
    x = "Ano",
    y = "Área (ha)",
    color = "Classe MapBiomas"
  ) +
  theme_minimal(base_size = 13)
# =========================
# 4. Gráfico por anos-chave
# =========================
anos_chave <- c(1985, 2000, 2010, 2023)

mb_tab %>%
  filter(ano %in% anos_chave) %>%
  ggplot(aes(x = nome, y = area_ha, fill = nome)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ano, scales = "free_y") +
  coord_flip() +
  labs(
    title = "Uso e cobertura do solo em anos selecionados",
    x = "Classe",
    y = "Área (ha)"
  ) +
  theme_minimal()

# =========================
# 5. Variação total
# =========================
ano_inicial <- min(mb_tab$ano)
ano_final   <- max(mb_tab$ano)

mb_variacao <- mb_tab %>%
  filter(ano %in% c(ano_inicial, ano_final)) %>%
  pivot_wider(
    names_from = ano,
    values_from = area_ha
  ) %>%
  mutate(
    variacao_ha =
      .[[as.character(ano_final)]] -
      .[[as.character(ano_inicial)]],
    variacao_percentual =
      (.[[as.character(ano_final)]] -
         .[[as.character(ano_inicial)]]) /
      .[[as.character(ano_inicial)]] * 100
  ) %>%
  arrange(desc(abs(variacao_ha)))

# =========================
# 6. Exportar resultados
# =========================
dir.create("resultados", showWarnings = FALSE)

write_csv(
  mb_tab,
  "resultados/uso_solo_microbacia_vai_e_vem_por_ano.csv"
)

write_csv(
  mb_variacao,
  "resultados/variacao_uso_solo_microbacia.csv"
)

#-----------------------------
#Gráficos
#-----------------------------

mb_grupo <- mb_tab %>%
  mutate(
    grupo = case_when(
      nome %in% c(
        "Formação Florestal",
        "Formação Savânica",
        "Formação Campestre"
      ) ~ "Vegetação natural",
      
      nome %in% c(
        "Pastagem",
        "Agricultura",
        "Mosaico de Agricultura e Pastagem"
      ) ~ "Agropecuária",
      
      nome %in% c(
        "Área Urbana",
        "Infraestrutura Urbana"
      ) ~ "Área urbana",
      
      nome %in% c(
        "Rio, Lago e Oceano",
        "Corpos d'água"
      ) ~ "Corpos d'água",
      
      TRUE ~ "Outros"
    )
  ) %>%
  group_by(ano, grupo) %>%
  summarise(area_ha = sum(area_ha), .groups = "drop")

cores_mapbiomas <- c(
  "Vegetação natural" = "#1f8f4a",
  "Agropecuária"      = "#ffd966",
  "Área urbana"       = "#e06666",
  "Corpos d'água"     = "#6fa8dc",
  "Outros"            = "#999999"
)

ggplot(mb_grupo, aes(x = ano, y = area_ha, color = grupo)) +
  geom_line(linewidth = 1.2) +
  scale_color_manual(values = cores_mapbiomas) +
  labs(
    title = "Mudança do uso e cobertura do solo\nMicrobacia do Ribeirão Vai e Vem",
    x = "Ano",
    y = "Área (ha)",
    color = "Classe"
  ) +
  theme_minimal()

ano_inicial <- min(mb_grupo$ano)
ano_final   <- max(mb_grupo$ano)
periodo     <- ano_final - ano_inicial

mb_taxa <- mb_grupo %>%
  filter(ano %in% c(ano_inicial, ano_final)) %>%
  pivot_wider(
    names_from = ano,
    values_from = area_ha
  ) %>%
  mutate(
    variacao_ha = .[[as.character(ano_final)]] -
      .[[as.character(ano_inicial)]],
    
    taxa_ha_ano = variacao_ha / periodo,
    
    taxa_percentual_ano =
      (variacao_ha / .[[as.character(ano_inicial)]]) / periodo * 100
  ) %>%
  arrange(desc(abs(variacao_ha)))

mb_taxa

write_csv(
  mb_grupo,
  "resultados/uso_solo_grupos_por_ano.csv"
)

write_csv(
  mb_taxa,
  "resultados/taxa_mudanca_uso_solo.csv"
)

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Etapa 4: Visualização e Exportação

# Gerar mapas temáticos com tmap ou ggplot2.
# Criar gráficos de mudança de uso do solo com ggplot2 e dygraphs.
# Exportar dados tabulares em CSV e shapefiles com sf.
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
