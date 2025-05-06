FROM rocker/r-base:latest

RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libpq-dev

RUN R -e "install.packages(c('rvest', 'DBI', 'RPostgres'), repos='https://cloud.r-project.org')"

WORKDIR /usr/src/app
COPY Advanced_Scraper_Mine.r .

CMD ["Rscript", "Advanced_Scraper_Mine.r"]
