#!/bin/bash

set -e

r_packages=(
  # base-r
  IRkernel
  remotes

  # essentials
  coursekata
  gridExtra
  fivethirtyeight
  fivethirtyeightdata
  testwhat
  ggpubr
  lme4
  minqa
  plotly
  statmod

  # r
  av
  bayesplot
  car
  dagitty
  emmeans
  gganimate
  ggdag
  gifski
  here
  mapdata
  mapproj
  maps
  neuralnet
  OCSdata
  posterior
  profvis
  psych
  RcppTOML
  reticulate
  simstudy
  tidymodels
  tidyverse
  gt
  gtsummary
  lmerTest
  broom.mixed
  DHARMa
  marginaleffects
  modelsummary
  easystats
  ggstatsplot
  janitor
  loo
  tidybayes
  datapasta

  # datascience
  brms
  cmdstanr
  ggstatsplot
  rstanarm
  rethinking
)

py_packages=(
  # base-r

  # essentials
  pythonwhat

  # r

  # datascience
  ipywidgets
  matplotlib
  nltk
  numpy
  openpyxl
  pandas
  plotly
  scikit-learn
  seaborn
  statsmodels
  cmdstanpy
  altair
  altair-latimes
  beautifulsoup4
  bokeh
  contextily
  dash
  dash-cytoscape
  folium
  gensim
  geopandas
  dtreeviz
  mapclassify
  networkx
  researchpy
  scipy
  spotipy
  vega_datasets
  wordcloud
  yahoo-fin
  yellowbrick
)

# set the cmdstan path because it won't be loaded when running this script with bash -c
export CMDSTAN="${CONDA_DIR}/bin/cmdstan"
Rscript -e "options(warn=2); cmdstanr::cmdstan_path() |> invisible()"

"$(dirname "$0")/test-r-packages.sh" "${r_packages[@]}" & r_pid=$!
"$(dirname "$0")/test-python-packages.sh" "${py_packages[@]}" & py_pid=$!
for job in $r_pid $py_pid; do wait $job || exit 1; done
echo -e "\033[32mAll tests passed!\033[0m"
