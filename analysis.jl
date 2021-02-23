using Pkg

# Pkg.add("SQLite")
# Pkg.add("DBInterface")
# Pkg.add("DataFrames")
# Pkg.add("Query")

using SQLite
using DBInterface
using DataFrames
using Query
using DataFramesMeta

namesDB = SQLite.DB("names.db")

namesDF = DBInterface.execute(namesDB, "SELECT * FROM names") |> DataFrame

girlsDF = @linq namesDF |>
        where(:sex .== "F") |>
        select(:name, :year)

boysDF = @linq namesDF |>
        where(:sex .== "M") |>
        select(:name, :year)

nG = nrow(unique(girlsDF,[:name]))
nB = nrow(unique(boysDF,[:name]))
nY = nrow(unique(namesDF, [:year]))