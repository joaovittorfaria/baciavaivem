#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Projeto de Pesquisa: PI05919-2025 - DIAGNÓSTICO DO USO E OCUPAÇÃO DO SOLO NA ÁREA DO ALTO CURSO DA MICROBACIA HIDROGRÁFICA DO RIBEIRÃO VAI-E-VEM NO MUNICÍPIO DE IPAMERI (GO)
# Orientador:	RAFAEL DE AVILA RODRIGUES ( Docente )
# Co-Orientador:	ANTOVER PANAZZOLO SARMENTO ( Docente )
# Centro:	UNIVERSIDADE FEDERAL DE CATALÃO
# Discente:	202301291 - JOAO VITTOR DE FARIA PEREIRA
# Objetivo: Criar um fluxo automatizado para a extração, processamento e análise de dados de uso e cobertura do solo na microbacia do Ribeirão Vai e Vem (Ipameri-GO), utilizando apenas a linguagem R e ferramentas de código aberto.
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Etapa 1: Delimitação da Área de Estudo

# Utilizar dados vetoriais da bacia hidrográfica obtidos do Instituto Brasileiro de Geografia e Estatística (IBGE) ou da Agência Nacional de Águas (ANA).
# Aplicar funções dos pacotes sf e terra para recortar a área de interesse (Ribeirão Vai e Vem – GO).
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Dados Usados do ANA: Base Hidrográfica Ottocodificada da Bacia do Rio Paranaíba, Trechos de drenagem e Áreas de contribuição Hidrográfica.
# https://metadados.snirh.gov.br/geonetwork/srv/por/catalog.search#/metadata/09436656-f4cf-4793-b169-33700b2d40ee

# 1.1 CRIAR PASTA DO PROJETO 
##############################

desktop <- file.path(Sys.getenv("USERPROFILE"), "Desktop")

# caso seja Linux ou Mac
if(!dir.exists(desktop)){
  desktop <- file.path(Sys.getenv("HOME"), "Desktop")
}

pasta_projeto <- file.path(desktop, "projetomicrobacia")

if(!dir.exists(pasta_projeto)){
  dir.create(pasta_projeto)
}

setwd(pasta_projeto)

cat("Diretório do projeto:", pasta_projeto, "\n")

# 1.2 INSTALAR E CARREGAR PACOTES 
###################################

pacotes <- c(
  "sf",
  "terra",
  "dplyr",
  "ggplot2",
  "mapview",
  "reticulate",
  "rgee",
  "geojsonio",
  "tidyverse",
  "readr",
  "tidyr",
  "xts",
  "dygraphs",
  "ggspatial"
)

instalar <- pacotes[!(pacotes %in% installed.packages()[,"Package"])]

if(length(instalar) > 0){
  install.packages(instalar, dependencies = TRUE)
}

invisible(lapply(pacotes, library, character.only = TRUE))

library(sf)
library(dplyr)
library(mapview)

sf_use_s2(FALSE)

cat("Pacotes carregados.\n")


# 1.3 CRIAR ESTRUTURA DE PASTAS 
#################################

pastas <- c(
  "dados",
  "dados/bacias",
  "dados/drenagem",
  "resultados",
  "resultados/tabelas",
  "resultados/rasters"
)

for(p in pastas){
  if(!dir.exists(p)){
    dir.create(p, recursive = TRUE)
  }
}

cat("Estrutura de pastas criada.\n")


# 1.4 DOWNLOAD DADOS DA ANA 
#############################

url_bacias <- "https://metadados.snirh.gov.br/files/09436656-f4cf-4793-b169-33700b2d40ee/GEOFT_BHO_AREACONTRIBUICAO.zip"

url_drenagem <- "https://metadados.snirh.gov.br/geonetwork/srv/api/records/09436656-f4cf-4793-b169-33700b2d40ee/attachments/geoft_bho_trecho_drenagem.zip"

dest_bacias <- "dados/bacias/bacias.zip"
dest_drenagem <- "dados/drenagem/drenagem.zip"


if(!file.exists(dest_bacias)){
  download.file(url_bacias, dest_bacias, mode = "wb")
  cat("Download das bacias concluído.\n")
}

if(!file.exists(dest_drenagem)){
  download.file(url_drenagem, dest_drenagem, mode = "wb")
  cat("Download da drenagem concluído.\n")
}

# 1.5 DESCOMPACTAR ARQUIVOS 
#############################

unzip(dest_bacias, exdir = "dados/bacias")
unzip(dest_drenagem, exdir = "dados/drenagem")

cat("Arquivos descompactados.\n")

# 1.6 CARREGAR SHAPEFILES 
###########################

arquivo_bacias <- list.files(
  "dados/bacias",
  pattern = ".shp$",
  full.names = TRUE
)

arquivo_drenagem <- list.files(
  "dados/drenagem",
  pattern = ".shp$",
  full.names = TRUE
)

bacias <- st_read(arquivo_bacias)

drenagem <- st_read(arquivo_drenagem)

drenagem <- st_transform(drenagem, st_crs(bacias))

bacias <- st_make_valid(bacias)
drenagem <- st_make_valid(drenagem)

# 1.7 PONTO DE EXUTÓRIO 
#########################

ponto_exutorio <- st_sfc(
  st_point(c(-48.159, -17.722)),
  crs = 4674
)

ponto_exutorio <- st_as_sf(
  data.frame(id = 1, geometry = ponto_exutorio)
)


# 1.8 TRECHO PRÓXIMO E AJUSTE DO EXUTÓRIO
##########################################

# calcular distância do ponto até todos os rios
dist <- st_distance(ponto_exutorio, drenagem)

# identificar o rio mais próximo
trecho_id <- which.min(dist)

trecho_principal <- drenagem[trecho_id, ]

# mover o ponto exatamente para o rio (snap)
ponto_exutorio <- st_nearest_points(
  ponto_exutorio,
  trecho_principal
)

# pegar apenas o ponto final da linha criada
ponto_exutorio <- st_cast(ponto_exutorio, "POINT")[2]

ponto_exutorio <- st_as_sf(
  data.frame(id = 1, geometry = ponto_exutorio)
)

print(trecho_principal$COBACIA)


# 1.9 SELECIONAR MICROBACIA
#############################

codigo_bacia <- trecho_principal$COBACIA

bacia_micro <- bacias[
  bacias$COBACIA == codigo_bacia,
]

bacia_micro <- st_union(bacia_micro)

bacia_micro <- st_as_sf(
  data.frame(id = 1, geometry = bacia_micro)
)

drenagem_micro <- st_intersection(
  drenagem,
  bacia_micro
)


bacia_utm <- st_transform(
  bacia_micro,
  31983
)

area_km2 <- as.numeric(st_area(bacia_utm)) / 1000000

cat("Área da microbacia (km²):", area_km2, "\n")

# 1.10 EXPORTAÇÃO DE IMAGEM
#############################

mapview(bacia_micro,
        col.regions = "lightgreen",
        alpha.regions = 0.4,
        layer.name = "Microbacia") +
  
  mapview(drenagem_micro,
          color = "blue",
          lwd = 2,
          layer.name = "Drenagem") +
  
  mapview(ponto_exutorio,
          col.regions = "red",
          cex = 6,
          layer.name = "Exutório")

# 1.11 EXPORTAÇÃO ARQUIVO
##########################

st_write(
  bacia_micro,
  "resultados/rasters/microbacia_vai_e_vem_alto_curso.shp",
  delete_layer = TRUE
)

names(drenagem)

st_within(
  ponto_exutorio,
  bacia_micro
)

#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#Etapa 2: Extração de Dados de Uso do Solo

#Usar o pacote rgee para conectar-se ao Google Earth Engine e extrair as imagens da Coleção 9 do MapBiomas (MapBiomas Brasil, 2024).
#Selecionar bandas correspondentes aos anos de 1985 a 2023.
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# 2.1 DOWNLOAD ARQUIVOS RASTER, TERRA USANDO EARTH ENGINE
###########################################################

library(terra)

# garantir pasta mapbiomas
if(!dir.exists("dados/mapbiomas")){
  dir.create("dados/mapbiomas")
}

url_mapbiomas <- "https://raw.githubusercontent.com/joaovittorfaria/baciavaivem/main/mapbiomas_microbacia_1985_2023.tif"

destino <- "dados/mapbiomas/mapbiomas_microbacia_1985_2023.tif"

if(!file.exists(destino)){
  
  download.file(
    url = url_mapbiomas,
    destfile = destino,
    mode = "wb"
  )
  
  cat("Raster MapBiomas baixado com sucesso.\n")
  
} else {
  
  cat("Raster já existe na pasta dados/mapbiomas.\n")
}

# 2.2 CARREGAR RASTER
########################

mapbiomas <- rast(destino)

cat("Raster MapBiomas carregado.\n")

# verificar número de bandas
nlyr(mapbiomas)

# 2.3 BANDAS DE 1985 A 2023
#############################

anos <- 1985:2023

names(mapbiomas) <- paste0("classification_", anos)

cat("Bandas nomeadas de 1985 a 2023.\n")

# 2.4 RECORTAR RASTER PARA A MICROBACIA
########################################

bacia_vect <- vect(bacia_micro)

mapbiomas_crop <- crop(mapbiomas, bacia_vect)

mapbiomas_mask <- mask(mapbiomas_crop, bacia_vect)

cat("Raster recortado para a área da microbacia.\n")


# 2.5 SALVAR DADOS ANO A ANO
#############################

for(i in 1:nlyr(mapbiomas_mask)){
  
  ano <- anos[i]
  
  writeRaster(
    mapbiomas_mask[[i]],
    paste0("resultados/rasters/mapbiomas_", ano, ".tif"),
    overwrite = TRUE
  )
}

cat("Rasters anuais exportados.\n")

#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Etapa 3: Processamento e Análise Espacial

# Recortar os dados do MapBiomas usando a geometria da microbacia.
# Classificar os valores de pixel conforme legenda oficial do MapBiomas.
# Calcular proporção de cada classe de uso do solo por ano.
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

library(terra)
library(sf)
library(dplyr)
library(tidyr)
library(purrr)

# 3.1 BAIXAR RASTER MAPBIOMAS
##############################

url_mapbiomas <- "https://raw.githubusercontent.com/joaovittorfaria/baciavaivem/main/mapbiomas_microbacia_1985_2023.tif"

dir.create("dados/mapbiomas", recursive = TRUE, showWarnings = FALSE)

destino <- "dados/mapbiomas/mapbiomas_microbacia_1985_2023.tif"

if(!file.exists(destino)){
  
  download.file(
    url = url_mapbiomas,
    destfile = destino,
    mode = "wb"
  )
  
}

# 3.2 CARREGAR RASTER
######################

mapbiomas <- rast(destino)

anos <- 1985:2023

names(mapbiomas) <- paste0("classification_", anos)

# 3.3 AJUSTAR CRS 
###################

bacia_micro <- st_transform(
  bacia_micro,
  crs(mapbiomas)
)

bacia_vect <- vect(bacia_micro)

# 3.4 RECORTAR RASTER MICROBACIA
######################################

mapbiomas <- crop(mapbiomas, bacia_vect)
mapbiomas <- mask(mapbiomas, bacia_vect)

# 3.5 LEGENDA OFICIAL MAPBIOMAS
################################

legenda_mapbiomas <- data.frame(
  
  classe = c(
    3,4,5,6,
    9,
    11,12,13,
    15,
    18,19,
    21,
    24,
    25,
    29,
    33
  ),
  
  nome = c(
    "Formação Florestal",
    "Formação Savânica",
    "Mangue",
    "Floresta Alagável",
    "Floresta Plantada",
    "Área Úmida Natural",
    "Formação Natural não Florestal",
    "Campo Alagado",
    "Pastagem",
    "Agricultura",
    "Lavoura Temporária",
    "Mosaico Agricultura/Pastagem",
    "Área Urbana",
    "Outras Áreas Não Vegetadas",
    "Afloramento Rochoso",
    "Corpos d'Água"
  )
  
)

# 3.6 FUNÇÃO PARA CALCULAR ÁREA POR CLASSE
###########################################

calc_area <- function(r, ano){
  
  r[r == 0] <- NA
  
  freq <- terra::freq(r)
  
  if(is.null(freq)) return(NULL)
  
  df <- as.data.frame(freq)
  
  df <- df[,c("value","count")]
  
  colnames(df) <- c("classe","pixels")
  
  df$area_ha <- df$pixels * 900 / 10000
  
  df$ano <- ano
  
  df
  
}

# 3.7 CALCULAR ÁREA PARA TODOS OS ANOS
#######################################

mb_tab <- map_dfr(
  
  seq_along(anos),
  
  ~calc_area(mapbiomas[[.x]], anos[.x])
  
)


# 3.8 NOMEANDO CLASSES
########################

mb_tab <- left_join(
  mb_tab,
  legenda_mapbiomas,
  by="classe"
)

# 3.9 CALCULAR PROPORÇÃO POR ANO
##################################

mb_tab <- mb_tab %>%
  
  group_by(ano) %>%
  
  mutate(
    area_total = sum(area_ha),
    
    proporcao_percent =
      area_ha / area_total * 100
  ) %>%
  
  ungroup()


# 3.10 EXTRAÇÃO RESULTADOS
############################

resultado_uso_solo <- mb_tab %>%
  
  select(
    ano,
    classe,
    nome,
    area_ha,
    proporcao_percent
  )

#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Etapa 4: Visualização e Exportação

# Gerar mapas temáticos com tmap ou ggplot2.
# Criar gráficos de mudança de uso do solo com ggplot2 e dygraphs.
# Exportar dados tabulares em CSV e shapefiles com sf.
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

library(ggplot2)
library(dplyr)
library(tidyr)
library(sf)
library(terra)
library(dygraphs)
library(xts)

# 4.1 CRIAÇÃO PASTAS
########################

dir.create("resultados", showWarnings = FALSE)

dir.create("resultados/mapas",
           recursive = TRUE,
           showWarnings = FALSE)

dir.create("resultados/graficos",
           recursive = TRUE,
           showWarnings = FALSE)

dir.create("resultados/tabelas",
           recursive = TRUE,
           showWarnings = FALSE)

# 4.2 LEGENDA MAP BIOMAS
##########################

legenda_mapbiomas <- data.frame(
  
  classe = c(
    3,4,9,11,
    15,
    21,
    24,
    25,
    33,
    39,
    41
  ),
  
  nome = c(
    "Formação Florestal",
    "Formação Savânica",
    "Floresta Plantada",
    "Área Úmida Natural",
    "Pastagem",
    "Mosaico Agricultura/Pastagem",
    "Área Urbana",
    "Outras Áreas Não Vegetadas",
    "Corpos d'Água",
    "Soja",
    "Algodão"
  )
)

cores_mapbiomas <- c(
  
  "Formação Florestal"="#006400",
  "Formação Savânica"="#00FF00",
  "Floresta Plantada"="#4CAF50",
  "Área Úmida Natural"="#B8AF4F",
  "Pastagem"="#FF6D4C",
  "Mosaico Agricultura/Pastagem"="#FFD966",
  "Área Urbana"="#E06666",
  "Outras Áreas Não Vegetadas"="#D3D3D3",
  "Corpos d'Água"="#6FA8DC",
  "Soja"="#FFD700",
  "Algodão"="#FFF2CC"
  
)

resultado_uso_solo <- as.data.frame(resultado_uso_solo)

colnames(resultado_uso_solo) <- c(
  "ano",
  "classe",
  "nome",
  "area_ha",
  "proporcao_percent"
)

resultado_uso_solo <- resultado_uso_solo %>%
  filter(!is.na(nome))

#############################
# 4.3 MAPA ANOS 1985 A 2023
#############################

library(ggplot2)
library(dplyr)
library(sf)

anos <- 1985:2023

for(a in anos){
  
  r <- mapbiomas[[paste0("classification_",a)]]
  
  r[r == 0] <- NA
  
  df <- as.data.frame(
    r,
    xy = TRUE,
    na.rm = TRUE
  )
  
  colnames(df) <- c("x","y","classe")
  
  df <- df %>%
    left_join(legenda_mapbiomas, by = "classe")
  
  df$nome[is.na(df$nome)] <- "Outras Áreas Não Vegetadas"
  
  # calcular proporção por classe
  prop_classes <- df %>%
    count(nome) %>%
    mutate(
      prop = (n / sum(n)) * 100,
      legenda = paste0(nome, " (", round(prop,1), "%)")
    )
  
  # criar labels da legenda
  labels_legenda <- prop_classes$legenda
  names(labels_legenda) <- prop_classes$nome
  
  
  mapa <- ggplot() +
    
    geom_raster(
      data = df,
      aes(x = x, y = y, fill = nome)
    ) +
    
    geom_sf(
      data = bacia_micro,
      fill = NA,
      color = "black",
      linewidth = 1
    ) +
    
    scale_fill_manual(
      values = cores_mapbiomas,
      breaks = names(labels_legenda),
      labels = labels_legenda,
      name = "Uso do Solo",
      guide = guide_legend(
        title.position = "top",
        title.hjust = 0.5
      )
    ) +
    
    coord_sf(expand = FALSE) +
    
    labs(
      title = paste("Uso e Cobertura do Solo -", a),
      subtitle = "Microbacia Ribeirão Vai-e-Vem",
      x = "Longitude",
      y = "Latitude"
    ) +
    
    theme_classic() +
    
    theme(
      
      plot.title = element_text(
        size = 16,
        face = "bold",
        hjust = 0.5
      ),
      
      plot.subtitle = element_text(
        size = 12,
        hjust = 0.5
      ),
      
      axis.text = element_text(size = 9),
      axis.title = element_text(size = 11),
      
      legend.title = element_text(
        size = 12,
        face = "bold"
      ),
      
      legend.text = element_text(size = 10),
      
      legend.key.size = unit(0.6, "cm"),
      
      legend.position = "right"
    )
  
  ggsave(
    filename = paste0("resultados/mapas/mapa_uso_solo_",a,".png"),
    plot = mapa,
    width = 8,
    height = 6,
    dpi = 300
  )
  
}

# 4.4 GRÁFICO TEMPORAL
#######################

grafico_temporal <- ggplot(
  resultado_uso_solo,
  aes(
    x = ano,
    y = proporcao_percent,
    color = nome
  )
) +
  
  geom_line(linewidth = 1.2) +
  
  labs(
    title = "Mudança do Uso e Cobertura do Solo",
    subtitle = "Microbacia Ribeirão Vai-e-Vem (1985–2023)",
    x = "Ano",
    y = "Proporção (%)",
    color = "Classe"
  ) +
  
  theme_minimal()

ggsave(
  "resultados/graficos/mudanca_uso_solo.png",
  grafico_temporal,
  width = 9,
  height = 6,
  dpi = 300
)

print(grafico_temporal)

# 4.5 GRÁFICO INTERATIVO
###########################

dados_dy <- resultado_uso_solo %>%
  
  group_by(ano, nome) %>%
  
  summarise(
    proporcao_percent = sum(proporcao_percent),
    .groups = "drop"
  ) %>%
  
  pivot_wider(
    names_from = nome,
    values_from = proporcao_percent,
    values_fill = 0
  )

dados_dy[,-1] <- lapply(dados_dy[,-1], as.numeric)

dados_xts <- xts(
  dados_dy[,-1],
  order.by = as.Date(paste0(dados_dy$ano,"-01-01"))
)

grafico_interativo <- dygraph(dados_xts) %>%
  dyRangeSelector() %>%
  dyOptions(stackedGraph = TRUE)

grafico_interativo

# 4.6 EXPORTAR TABELA
########################

write.csv2(
  resultado_uso_solo,
  "resultados/tabelas/uso_solo_proporcao_por_ano.csv",
  row.names = FALSE
)

anos_comparacao <- c(1985, 2023)

comparacao <- resultado_uso_solo %>%
  filter(ano %in% anos_comparacao)

grafico_barra <- ggplot(
  comparacao,
  aes(
    x = nome,
    y = area_ha,
    fill = factor(ano)
  )
) +
  
  geom_bar(stat = "identity", position = "dodge") +
  
  coord_flip() +
  
  labs(
    title = "Comparação do Uso do Solo",
    subtitle = "1985 vs 2023",
    x = "Classe",
    y = "Área (ha)",
    fill = "Ano"
  ) +
  
  theme_minimal()

ggsave(
  "resultados/graficos/comparacao_1985_2023.png",
  grafico_barra,
  width = 9,
  height = 6,
  dpi = 300
)

mudanca_anual <- resultado_uso_solo %>%
  
  arrange(nome, ano) %>%
  
  group_by(nome) %>%
  
  mutate(
    area_ano_anterior = lag(area_ha),
    
    mudanca_ha = area_ha - area_ano_anterior,
    
    mudanca_percent =
      (mudanca_ha / area_ano_anterior) * 100
  ) %>%
  
  ungroup()

write.csv2(
  mudanca_anual,
  "resultados/tabelas/mudanca_anual_uso_solo.csv",
  row.names = FALSE
)

grafico_area_empilhada <- ggplot(
  resultado_uso_solo,
  aes(
    x = ano,
    y = proporcao_percent,
    fill = nome
  )
) +
  
  geom_area() +
  
  labs(
    title = "Evolução do Uso do Solo",
    subtitle = "Microbacia Ribeirão Vai-e-Vem",
    x = "Ano",
    y = "Proporção (%)",
    fill = "Classe"
  ) +
  
  theme_minimal()

ggsave(
  "resultados/graficos/area_empilhada.png",
  grafico_area_empilhada,
  width = 9,
  height = 6,
  dpi = 300
)

resumo_classes <- resultado_uso_solo %>%
  
  group_by(nome) %>%
  
  summarise(
    area_media = mean(area_ha),
    area_maxima = max(area_ha),
    area_minima = min(area_ha),
    .groups = "drop"
  )

write.csv2(
  resumo_classes,
  "resultados/tabelas/resumo_estatistico_classes.csv",
  row.names = FALSE
)

# 4.8 MAPA HOTSPOTS
#####################

# contar quantas vezes cada pixel mudou de classe
mudancas <- mapbiomas[[1]]

mudancas[] <- 0

for(i in 2:nlyr(mapbiomas)){
  
  mudou <- mapbiomas[[i]] != mapbiomas[[i-1]]
  
  mudancas <- mudancas + mudou
  
}

writeRaster(
  mudancas,
  "resultados/rasters/hotspots_mudanca.tif",
  overwrite = TRUE
)

df_hotspot <- as.data.frame(
  mudancas,
  xy = TRUE,
  na.rm = TRUE
)

colnames(df_hotspot) <- c("x","y","mudancas")

mapa_hotspot <- ggplot() +
  
  geom_raster(
    data = df_hotspot,
    aes(
      x = x,
      y = y,
      fill = mudancas
    )
  ) +
  
  geom_sf(
    data = bacia_micro,
    fill = NA,
    color = "black"
  ) +
  
  scale_fill_viridis_c(
    name = "Nº de mudanças"
  ) +
  
  labs(
    title = "Hotspots de Mudança do Uso do Solo",
    subtitle = "1985–2023"
  ) +
  
  theme_minimal()

ggsave(
  "resultados/mapas/hotspots_mudanca.png",
  mapa_hotspot,
  width = 8,
  height = 6,
  dpi = 300
)

# 4.9 CSV TAXA MUDANÇA ANUAL
#############################

taxa_mudanca <- resultado_uso_solo %>%
  
  group_by(nome) %>%
  
  arrange(ano) %>%
  
  mutate(
    taxa_anual = (proporcao_percent - lag(proporcao_percent))
  ) %>%
  
  ungroup()

write.csv2(
  taxa_mudanca,
  "resultados/tabelas/taxa_anual_mudanca.csv",
  row.names = FALSE
)

print(grafico_temporal)
print(grafico_barra)
print(grafico_area_empilhada)
print(mapa_hotspot)
