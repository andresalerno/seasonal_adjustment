
# Document Information ----
my.d <- rstudioapi::getActiveDocumentContext()

# Document Path ----
my.file.location <- rstudioapi::getActiveDocumentContext()$path

# Directory Path ----
my.dir <- dirname(my.file.location)

# Setting up the working directory ----
setwd(my.dir)

# Loading important libraries ----
if(!require("fpp")) install.packages("fpp")
if(!require("fpp2")) install.packages("fpp2")
if(!require("seasonal")) install.packages("seasonal")

library(DBI)
library(fpp)
library(fpp2)
library(RMySQL)
library(dplyr)


# 1) Fetching data using read.table() ----

file_csv <- read.table(file = "balancete_sjc.csv",
                       header = TRUE,
                       na.strings = "EMPTY",
                       colClasses = c("character", "character", "character", "character", "character", "character", "character", "numeric", "numeric", "numeric", "integer", "character"),
                       sep = ";",
                       strip.white = TRUE)

# 2) Deleting empty columns ----

file_csv[,13:16] <- NULL

# 3) Connection ----

con <- dbConnect(RMySQL::MySQL(),
                 dbname = "public_data",
                 host = "198.199.73.180",
                 port = 3306,
                 user = "root",
                 password = "aspartners2018")

dbSendQuery(con, "USE public_data")

dbWriteTable(con, file_csv, name = "gestao_sjc", append = TRUE, row.names = FALSE)

dbListTables(con)

# 4) Fetching IPCA ----

library(sidrar)

tabela_ipca <- get_sidra(api='/t/1419/p/201201-201809/v/63/C315/7169/n7/3501')

times <- seq(as.Date('2012-01-01'), as.Date('2018-09-01'), by='month')

ipca <- data.frame(time=times, ipca=tail(tabela_ipca$Valor, 81))

write.csv(ipca, file = "ipca.csv")

# 5) Fetching specific columns ----

# Table review

print(dbGetQuery(con, "gestao_sjc;"))

receitas_correntes <- dbGetQuery(con,
"SELECT `yyyy.mm`, descricao, valores_mes from gestao_sjc where descricao = 'RECEITAS CORRENTES';")

# Adding ipca$ipca month
receitas_correntes <- cbind(receitas_correntes, ipca$ipca)

# Changing column name
names(receitas_correntes)[4]<-paste("ipca_mes")

# Deflation
receitas_correntes <- receitas_correntes %>%
  mutate(valores_mes, valores_ajustados = valores_mes / (1 + (ipca$ipca/100)))

# Seasonal adjustment