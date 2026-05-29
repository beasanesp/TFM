# Cargar librerías
library(tidyverse)
library(patchwork)
library(extrafont)

loadfonts() 

# Asumiendo que feature_imp ya está cargado en el entorno
datos <- feature_imp

# Convertir los datos a formato largo
datos_largos <- datos %>%
  pivot_longer(cols = -Feature.importance,
               names_to = "Modelo",
               values_to = "Valor")

# Crear lista de gráficos sin leyenda
graficos <- datos_largos %>%
  group_split(Modelo) %>%
  map(function(df) {
    ggplot(df, aes(y = fct_reorder(Feature.importance, Valor),  x = Valor, fill= Feature.importance)) +
      geom_col() +
      labs(title = df$Modelo[1],
           x = "Valor",
           fill="Feature") +
      theme_minimal(base_size = 11, base_family = "Times New Roman") +
      xlim(0,0.5) +
      scale_fill_brewer(palette = "Set3") +
      theme(legend.position = "none")
  })

# Mostrar todos los gráficos juntos (por ejemplo 2 columnas)
grid.arrange(grobs = graficos, ncol = 2)