#!/bin/bash

set -e

packages=(
  cmdstanr
)

py_packages=(
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
