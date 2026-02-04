# Sachet brand/manufacturer vs Ghana FDA registry:
# exact match, relaxed substring match, and robust fuzzy match (brand+manufacturer)
# Requires: readxl, dplyr, stringr, tidyr, stringdist

library(readxl)
library(dplyr)
library(stringr)
library(tidyr)
library(stringdist)

# ---- paths ----
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
registry_path <- "../Original Data/Ghana_FDA_Product_Registry_12312025.xlsx"

# ---- helpers ----
norm_txt <- function(x) {
  x <- ifelse(is.na(x), "", as.character(x))
  x <- str_to_lower(x)
  x <- str_replace_all(x, "[[:punct:]]+", " ")
  x <- str_replace_all(x, "\\s+", " ")
  str_trim(x)
}
tok <- function(x) {
  z <- str_split(norm_txt(x), "\\s+")[[1]]
  z[z != ""]
}

stop_brand <- c("natural","mineral","water","ice","pure","drink","drinking","bottled",
                "limited","ltd","company","co","enterprise","ent","ventures","services",
                "ghana","accra","kumasi","a/r","ashanti","gt","trading")
stop_firm  <- c("limited","ltd","company","co","enterprise","ent","ventures","services")

tok_rm <- function(x, stop) setdiff(tok(x), stop)

brand_score <- function(a, b) {
  ta <- tok_rm(a, stop_brand); tb <- tok_rm(b, stop_brand)
  if (length(ta) == 0 || length(tb) == 0) return(0)
  jacc <- length(intersect(ta, tb)) / length(union(ta, tb))
  jw   <- 1 - stringdist(a, b, method = "jw", p = 0.1)
  100 * (0.55 * jacc + 0.45 * jw)
}
manuf_score <- function(a, b) {
  if (is.na(a) || norm_txt(a) == "") return(NA_real_)
  jw <- 1 - stringdist(a, b, method = "jw", p = 0.1)
  ta <- tok_rm(a, stop_firm); tb <- tok_rm(b, stop_firm)
  jacc <- if (length(ta) == 0 || length(tb) == 0) 0 else length(intersect(ta, tb)) / length(union(ta, tb))
  100 * (0.35 * jacc + 0.65 * jw)
}

# ---- load registry ----
reg <- read_excel(registry_path) %>%
  mutate(
    product_norm  = norm_txt(`Product Name`),
    client_norm   = norm_txt(`Client Name`),
    category_norm = norm_txt(Category)
  )

# optional: restrict fuzzy search to water-like products (product name keywords + category fallback)
water_kw <- "water|mineral water|drinking water|natural mineral|ice|sachet|bottled"
reg_water <- reg %>%
  filter(str_detect(product_norm, water_kw) | str_detect(category_norm, "water|beverage|drink"))

# ---- sachet list ----
sachet <- tibble::tribble(
  ~sachet_brand_name, ~sachet_manuf_name,
  "BETHSADA", "CATAGA ENTERPRISE",
  "Unique Natural Mineral Water", "NHYIRABA AGYAPONG",
  "Kotak Natural Mineral Water", "Aqua Kotak Limited",
  "Dove Ice", "E  Boison 140 Ventures",
  "A&A Mineral Water", "Awgloss Company Limited",
  "Blessed One Natural Mineral Water", "Blessed One Enterprise",
  "Dansity", "Royal Dansity Investment International",
  "Unique Natural Mineral Water", "Nhyiraba Agyapong Enterprise",
  "TRY AQUAH", "TRY AQUAH MINERAL WATER",
  "Calva Nkwasuo", "Calvary Nkwasuo Enterprise",
  "Pure Ice", "Fredericko Esan Enterprise",
  "Babaqua Mineral Water", NA_character_,
  "One star", "God's Gift Mineral water",
  "PMP", "PRINMOPAG",
  "A&A Mineral Water", "Awgloss Company Limited"
) %>%
  mutate(
    brand_norm = norm_txt(sachet_brand_name),
    manuf_norm = norm_txt(sachet_manuf_name)
  )

# -------------------------------------------------------------------
# 1) EXACT MATCHES (product; and manufacturer if provided)
# -------------------------------------------------------------------
exact_matches <- sachet %>%
  left_join(
    reg %>% select(`Product Name`, `Client Name`, Category, Status, `Expiry Date`, Product_Details = `Product Details`,
                   product_norm, client_norm),
    by = c("brand_norm" = "product_norm")
  ) %>%
  mutate(
    manuf_missing = manuf_norm == "" | is.na(sachet_manuf_name),
    exact_hit = !is.na(`Product Name`) & (manuf_missing | manuf_norm == client_norm)
  ) %>%
  filter(exact_hit) %>%
  select(sachet_brand_name, sachet_manuf_name, `Product Name`, `Client Name`, Category, Status, `Expiry Date`, Product_Details)

# -------------------------------------------------------------------
# 2) RELAXED SUBSTRING MATCHES (brand in product/client; manufacturer in client if provided)
# -------------------------------------------------------------------
relaxed_matches <- sachet %>%
  mutate(brand_pat = brand_norm, manuf_pat = manuf_norm) %>%
  tidyr::crossing(
    reg %>% select(`Product Name`, `Client Name`, Category, Status, `Expiry Date`, Product_Details = `Product Details`,
                   product_norm, client_norm)
  ) %>%
  mutate(
    brand_hit = str_detect(product_norm, fixed(brand_pat)) | str_detect(client_norm, fixed(brand_pat)),
    manuf_hit = (manuf_pat == "" | is.na(sachet_manuf_name)) | str_detect(client_norm, fixed(manuf_pat)),
    relaxed_hit = brand_hit & manuf_hit
  ) %>%
  filter(relaxed_hit) %>%
  select(sachet_brand_name, sachet_manuf_name, `Product Name`, `Client Name`, Category, Status, `Expiry Date`, Product_Details)

# -------------------------------------------------------------------
# 3) ROBUST FUZZY SEARCH (top-k per sachet, then flag likely matches)
# -------------------------------------------------------------------
top_k <- 10

cands <- sachet %>%
  rowwise() %>%
  do({
    s <- .
    reg_water %>%
      mutate(
        bscore = brand_score(s$brand_norm, product_norm),
        mscore = manuf_score(s$manuf_norm, client_norm),
        comp   = if_else(is.na(mscore), bscore, 0.7 * bscore + 0.3 * mscore)
      ) %>%
      arrange(desc(comp)) %>%
      slice_head(n = top_k) %>%
      mutate(
        sachet_brand_name = s$sachet_brand_name,
        sachet_manuf_name = s$sachet_manuf_name
      ) %>%
      select(sachet_brand_name, sachet_manuf_name,
             `Product Name`, `Client Name`, Category, Status, `Expiry Date`,
             bscore, mscore, comp)
  }) %>%
  ungroup()

flagged <- cands %>%
  mutate(
    manuf_present = !(is.na(sachet_manuf_name) | norm_txt(sachet_manuf_name) == ""),
    likely_match = if_else(
      manuf_present,
      (bscore >= 92 & mscore >= 88) | comp >= 92,
      (bscore >= 94) | comp >= 94
    ),
    note = case_when(
      likely_match ~ "POSSIBLE MATCH (check manually)",
      bscore >= 85 ~ "brand close; likely generic-word collision",
      TRUE ~ "unlikely"
    )
  )

flagged_hits <- flagged %>% filter(likely_match)
top3 <- flagged %>% group_by(sachet_brand_name, sachet_manuf_name) %>% slice_head(n = 3) %>% ungroup()

# ---- outputs ----
cat("\nRegistry rows:", nrow(reg), "\n")
cat("Water-like subset rows:", nrow(reg_water), "\n")

cat("\nEXACT MATCHES:\n")
print(exact_matches)

cat("\nRELAXED SUBSTRING MATCHES:\n")
print(relaxed_matches)

cat("\nFLAGGED FUZZY HITS (manual verification):\n")
print(flagged_hits)

cat("\nTOP-3 FUZZY CANDIDATES PER SACHET (audit trail):\n")
print(top3, n = 50)
