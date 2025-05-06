# Tadviser

# Первый слой прасинга
library(rvest)

url <- "https://www.tadviser.ru/index.php/Карта_информатизации_бизнеса#"

webpage <- read_html(url)

hrefs <- webpage %>%
    html_nodes(".red_bloks") %>%
    html_nodes("a") %>%
    html_attr("href")

techno_titles <- webpage %>%
    html_nodes(".red_bloks") %>%
    html_nodes("a") %>%
    html_text()


# Второй слой парсинга

add = "?cache=no&ptype=system#ttop"
techno_table <- list()
for (href_num in seq_along(hrefs[1:2])) {
    webpage <- read_html(paste0("https://www.tadviser.ru", hrefs[href_num], add))
    table <- webpage %>%
        html_node(".sortable.cwiki_table") %>%
        html_table()

    table$product_links <- webpage %>%
        html_nodes(".sortable.cwiki_table td:first-child") %>% # извлекаем все элементы первого столбца таблицы
        html_nodes("a") %>%
        html_attr("href")

    techno_table[[techno_titles[href_num]]] <- table
}

# Третий слой парсинга

for (i in seq_along(techno_table)) {
    links <- techno_table[[i]]$product_links

    attrs_list <- rep(list(NULL), length(links))
    # В целях экономии времени мы спарсим только первые две ссылки
    for (j in 1:2) {
        link <- links[j]
        page <- read_html(paste0("https://www.tadviser.ru", link))
        table <- html_node(page, "table.atts_table") %>% html_table()
        attrs_list[[j]] <- table
    }

    techno_table[[i]]$product_attrs <- attrs_list
}
