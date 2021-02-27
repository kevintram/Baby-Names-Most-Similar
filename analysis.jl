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
using LinearAlgebra

namesDB = SQLite.DB("names.db")

namesDF = DBInterface.execute(namesDB, "SELECT * FROM names") |> DataFrame

firstYear = first(namesDF).year
lastYear = last(namesDF).year

# Get all unique girl names.
gDF = unique(@linq namesDF |>
        where(:sex .== "F") |>
        select(:name))

# Get all unique boy names.
bDF = unique(@linq namesDF |>
        where(:sex .== "M") |>
        select(:name))

nG = nrow(gDF)
nB = nrow(bDF)
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
bBM = createNameIndexBiMap(bDF)
gBM = createNameIndexBiMap(gDF)

# Counts of boy names and girl names. Fb[bBM[name],year] will return the count of the name of the year.
Fb = OffsetArray(zeros(Int32, nB, nY), 1:nB, firstYear:lastYear)
Fg = OffsetArray(zeros(Int32, nG, nY), 1:nG, firstYear:lastYear)

# Populate Fb and Fg matrices.
for row in Tables.rows(namesDF)
        i = 0
        if (row.sex == "F") 
                i = gBM[row.name]
                Fg[i, row.year] = row.num
        else
                i = bBM[row.name]
                Fb[i, row.year] = row.num
        end
end

Ty = OffsetArray(zeros(Int64, nY), firstYear:lastYear)

# Populate Ty.
for row in Tables.rows(namesDF)
        Ty[row.year] += row.num
end

# Returns probability matrix from the given count matrix and year vector.
function getProbabilityMatrix(F, Ty)
        nRange = axes(F,1)
        yearRange = axes(F,2)
        P = OffsetArray(zeros(length(nRange), length(yearRange)), nRange, yearRange)

        for i = nRange
                for year = yearRange
                        P[i,year] = F[i,year] / Ty[year]
                end
        end
        P
end;

Pb = getProbabilityMatrix(Fb, Ty)
Pg = getProbabilityMatrix(Fg, Ty)

# Returns the matrix with every row normalized.
function getRowNormalized(P)
        Q = copy(P)
        for row in eachrow(Q)
                normRow = normalize!(row)
        end
        Q
end;

Qb = getRowNormalized(Pb)
Qg = getRowNormalized(Pg)