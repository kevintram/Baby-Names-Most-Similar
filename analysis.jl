using Pkg

# Pkg.add("SQLite")
# Pkg.add("DBInterface")
# Pkg.add("DataFrames")
# Pkg.add("Query")
# Pkg.add("Bijections")
# Pkg.add("OffsetArrays")
# Pkg.add("BlockArrays")
# Pkg.add("Gadfly")

using SQLite
using DBInterface
using DataFrames
using Query
using DataFramesMeta
using Bijections
using OffsetArrays
using LinearAlgebra
using BlockArrays
# using Gadfly

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
Fb = zeros(Int32, nB, nY)
Fg = zeros(Int32, nG, nY)


function getYearIndex(year) 
        year - firstYear + 1
end

# Populate Fb and Fg matrices.
for row in Tables.rows(namesDF)
        i = 0
        if (row.sex == "F") 
                i = gBM[row.name]
                Fg[i, getYearIndex(row.year)] = row.num
        else
                i = bBM[row.name]
                Fb[i, getYearIndex(row.year)] = row.num
        end
end

#indexed by year (so no need to use getYearIndex())
Ty = OffsetArray(zeros(Int64, nY), firstYear:lastYear)

# Populate Ty.
for row in Tables.rows(namesDF)
        Ty[row.year] += row.num
end

# Returns probability matrix from the given count matrix and year vector.
function getProbabilityMatrix(F, Ty)
        nRange = axes(F,1)
        yearRange = axes(Ty,1)

        P = zeros(length(nRange), length(yearRange))

        for i = nRange
                for year = yearRange
                        P[i,getYearIndex(year)] = F[i,getYearIndex(year)] / Ty[year]
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

# n is the number of names
# returns the parition size array
function getPartitionNAxis(n)
        blockSize = convert(Int64, floor(n / 10))
        bBlockFirstAxis = [
                blockSize, 
                blockSize, 
                blockSize, 
                blockSize, 
                blockSize, 
                blockSize, 
                blockSize, 
                blockSize, 
                blockSize, 
                blockSize + n % 10
        ]
end;

# partition the matrices
bBlocked = BlockArray(Qb, getPartitionNAxis(nB), [nY])
gBlocked = BlockArray(Qg, getPartitionNAxis(nG), [nY])

# compute the dot product between every boy girl pair for every matrix
# by doing A * B^T (doing transpose of T will make the resultant matrix, C
# a matrix of dot products between every pair where C[i,j] corresponds
# to the dot product between the pairs of names A[i] and B[j]).

#block sizes for adjusting index later
bBlockSize = convert(Int64, floor(nB / 10))
gBlockSize = convert(Int64, floor(nG / 10))
maxVal = 0
maxIndex = (0,0) # first is boy name, second is girl name
for i in 1:10
        bBlock = getblock(bBlocked, i, 1)
        for j in 1:10
                gBlock = getblock(gBlocked, j, 1)
                product = bBlock * transpose(gBlock)

                m = findmax(product)
                val = m[1]
                index = (
                        m[2][1] + ((i - 1) * bBlockSize),
                        m[2][2] + ((j - 1) * gBlockSize)
                )

                global maxVal
                global maxIndex

                if (val > maxVal)
                        maxVal = val
                        maxIndex = index
                end
        end
end

bName = bBM(maxIndex[1])
gName = gBM(maxIndex[2])
println("The most similar boy and girl name are: $(bName) and $(gName)")