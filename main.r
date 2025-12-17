# =========================================================
# ETAPA 1 — DELIMITAÇÃO DA ÁREA DE ESTUDO
# Microbacia do Ribeirão Vai e Vem (Ipameri - GO)
# =========================================================

# -------------------------
# 1. PACOTES
# -------------------------
if (!requireNamespace("sf", quietly = TRUE)) install.packages("sf")
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
if (!requireNamespace("mapview", quietly = TRUE)) install.packages("mapview")

library(sf)
library(dplyr)
library(mapview)

# -------------------------
# 2. LEITURA DO SHAPEFILE
# -------------------------
message("Selecione o shapefile das bacias hidrográficas")
caminho_bacia <- file.choose()

bacia_sf <- st_read(caminho_bacia, quiet = FALSE)

# -------------------------
# 3. CONFERÊNCIA DE ATRIBUTOS
# -------------------------
message("Colunas disponíveis no shapefile:")
print(names(bacia_sf))

# -------------------------
# 4. TRANSFORMAÇÃO DE CRS
# SIRGAS 2000 (EPSG:4674) — padrão nacional
# -------------------------
bacia_sf <- st_transform(bacia_sf, 4674)

# Visualização inicial
mapview(bacia_sf, layer.name = "Bacias hidrográficas")

# -------------------------
# 5. FILTRO DA MICROBACIA
# Ajuste o nome da coluna se necessário
# -------------------------
if ("nome_bacia" %in% names(bacia_sf)) {
  
  bacia_vai_e_vem <- bacia_sf %>%
    filter(grepl("vai", nome_bacia, ignore.case = TRUE))
  
} else {
  stop(
    "O shapefile não possui a coluna 'nome_bacia'. 
    Verifique o nome correto do atributo."
  )
}

# Conferência
message("Número de feições após o filtro:")
print(nrow(bacia_vai_e_vem))

# -------------------------
# 6. DISSOLVER GEOMETRIA (GARANTIR UMA ÚNICA MICROBACIA)
# -------------------------
bacia_vai_e_vem <- bacia_vai_e_vem %>%
  summarise(geometry = st_union(geometry))

# -------------------------
# 7. PREPARAÇÃO PARA O GOOGLE EARTH ENGINE
# - Geometria válida
# - WGS84 (EPSG:4326)
# -------------------------
bacia_vai_e_vem_gee <- bacia_vai_e_vem %>%
  st_make_valid() %>%
  st_transform(4326)

# Visualização final
mapview(bacia_vai_e_vem_gee, layer.name = "Microbacia Vai e Vem")

# -------------------------
# 8. EXPORTAÇÃO
# -------------------------
dir.create("data", showWarnings = FALSE)

st_write(
  bacia_vai_e_vem_gee,
  "data/microbacia_ribeirao_vai_e_vem.gpkg",
  delete_dsn = TRUE
)

# -------------------------
# 9. MENSAGEM FINAL
# -------------------------
message("ETAPA 1 CONCLUÍDA COM SUCESSO")
message("Arquivo salvo em: data/microbacia_ribeirao_vai_e_vem.gpkg")


# ==============================
# PYTHON + EARTH ENGINE (ETAPA 2)
# ==============================

library(reticulate)

# Definir Python ANTES do rgee
use_python(
  "C:/Users/joaov/miniconda3/envs/rgee_py2/python.exe",
  required = TRUE
)

library(rgee)

# Inicializar Earth Engine (UMA ÚNICA VEZ)
ee_Initialize(drive = TRUE)

# Garantir objeto ee
ee <- rgee::ee

ee$ImageCollection("COPERNICUS/S2")$size()$getInfo()


# ==============================
# PACOTES
# ==============================
library(sf)
library(rgee)

# Inicializar GEE
ee_Initialize(drive = TRUE)
ee <- rgee::ee

# Ler microbacia
microbacia_sf <- st_read(
  "data/microbacia_ribeirao_vai_e_vem.gpkg",
  quiet = TRUE
)

microbacia_sf <- microbacia_sf |>
  st_make_valid() |>
  st_transform(4326)

microbacia_ee <- sf_as_ee(microbacia_sf)

# Asset da coleção 10 (disponível publicamente)
mapbiomas10 <- ee$Image(
  "projects/mapbiomas-public/assets/brazil/lulc/collection10/mapbiomas_brazil_collection10_coverage_v2"
)

# Selecionando bandas como “classification_1985”, etc.
anos <- 1985:2024
bandas <- paste0("classification_", anos)

mapbiomas10_clip <- mapbiomas10$
  select(bandas)$
  clip(microbacia_ee)

# Verificando as bandas
mapbiomas10_clip$bandNames()$getInfo()


### ETAPA 3

library(tidyverse)

# =========================
# 1. Ler CSV do MapBiomas
# =========================
caminho_csv <- file.choose()
mb_raw <- read_csv(caminho_csv)

# Conferir estrutura
names(mb_raw)

# =========================
# 2. Organizar dados
# =========================
mb_tab <- mb_raw %>%
  select(
    ano,
    area_ha,
    classe,
    nome
  ) %>%
  mutate(
    ano = as.integer(ano),
    area_ha = as.numeric(area_ha)
  ) %>%
  group_by(ano, classe, nome) %>%
  summarise(area_ha = sum(area_ha), .groups = "drop")

# =========================
# 3. Gráfico temporal
# =========================
ggplot(mb_tab, aes(x = ano, y = area_ha, color = nome)) +
  geom_line(linewidth = 1) +
  labs(
    title = "Mudança do uso e cobertura do solo\nMicrobacia do Ribeirão Vai e Vem",
    x = "Ano",
    y = "Área (ha)",
    color = "Classe"
  ) +
  theme_minimal()

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

