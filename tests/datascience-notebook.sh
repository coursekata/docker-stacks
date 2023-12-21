#!/bin/bash

set -e

r_packages=(
  # base
  remotes
  IRkernel
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
  # r-notebook
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
  profvis
  psych
  RcppTOML
  reticulate
  simstudy
  tidymodels
  tidyverse
  # datascience-notebook
  cmdstanr
)

py_packages=(
  # base
  # essentials
  pythonwhat
  # r-notebook
  # datascience-notebook
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
  jupyter-dash
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

for package in "${r_packages[@]}"; do
  Rscript -e "suppressPackageStartupMessages(library($package))"
done

for package in "${py_packages[@]}"; do
  pip show $package &> /dev/null || (echo " ! Python package $package not found" && exit 1)
done

echo "All tests passed!"
