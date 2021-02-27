using Pkg

# Pkg.add("SQLite")
# Pkg.add("DBInterface")
# Pkg.add("DataFrames")
# Pkg.add("Query")
# Pkg.add("Bijections")

using SQLite
using DBInterface
using DataFrames
using Query
using DataFramesMeta
using Bijections

namesDB = SQLite.DB("names.db")

namesDF = DBInterface.execute(namesDB, "SELECT * FROM names") |> DataFrame

# get all unique girl names
girlsDF = unique(@linq namesDF |>
        where(:sex .== "F") |>
        select(:name))

# get all unique boys names
boysDF = unique(@linq namesDF |>
        where(:sex .== "M") |>
        select(:name))

nG = nrow(girlsDF)
nB = nrow(boysDF)
nY = nrow(unique(namesDF, [:year]))

function createNameIndexBiMap(df)::Bijection{String, Int32}
        bimap = Bijection{String,Int32}()
        i = 1
        for row in Tables.rows(df) 
                bimap[row.name] = i
                i += 1 # why does ++ not exist
        end
        bimap
end;

boyBiMap = createNameIndexBiMap(boysDF)
girlBiMap = createNameIndexBiMap(girlsDF)

