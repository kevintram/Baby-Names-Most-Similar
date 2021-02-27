using Pkg

# Pkg.add("SQLite")
# Pkg.add("DBInterface")
# Pkg.add("DataFrames")
# Pkg.add("Query")
# Pkg.add("Bijections")
# Pkg.add("OffsetArrays")

using SQLite
using DBInterface
using DataFrames
using Query
using DataFramesMeta
using Bijections
using OffsetArrays

namesDB = SQLite.DB("names.db")

namesDF = DBInterface.execute(namesDB, "SELECT * FROM names") |> DataFrame

firstYear = first(namesDF).year
lastYear = last(namesDF).year

# Get all unique girl names.
girlsDF = unique(@linq namesDF |>
        where(:sex .== "F") |>
        select(:name))

# Get all unique boy names.
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

# bidirectional map of names to the index it corresponds to in Fb. 
boyBiMap = createNameIndexBiMap(boysDF)
girlBiMap = createNameIndexBiMap(girlsDF)

# Counts of boy names and girl names. Fb[boyBiMap[name],year] will return the count of the name of the year.
Fb = OffsetArray(zeros(Int32, nB, nY), 1:nB, firstYear:lastYear)
Fg = OffsetArray(zeros(Int32, nG, nY), 1:nG, firstYear:lastYear)

# Populate Fb and Fg matrices.
for row in Tables.rows(namesDF)
        i = 0
        if (row.sex == "F") 
                i = girlBiMap[row.name]
                Fg[i, row.year] = row.num
        else
                i = boyBiMap[row.name]
                Fb[i, row.year] = row.num
        end
end

Ty = OffsetArray(zeros(Int64, nY), firstYear:lastYear)

# Populate Ty.
for row in Tables.rows(namesDF)
        Ty[row.year] += row.num
end