"""
$(TYPEDEF)
    
Adjacency struct. Essentially, this is the sparsity pattern of a matrix whose
nonzero elements all have the same value in the CSC format.
"""
struct VariableTargetAdjacency{T}
    """
    Column entries: row indices of this column
    """
    colentries::Vector{T}

    """
    Start indices of respective column data in `colentries`
    """
    colstart::Vector{T}
end

"""
    $(SIGNATURES)
    
    Comparison of two adjacencies
"""
function Base.:(==)(a::VariableTargetAdjacency{Ta}, b::VariableTargetAdjacency{Tb}) where {Ta,Tb}
    Ta==Tb && a.colentries==b.colentries &&  a.colstart==b.colstart
end             

"""
$(TYPEDSIGNATURES)

Create an empty VariableTargetAdjacency
"""
VariableTargetAdjacency(t::Type{T}) where T=VariableTargetAdjacency{T}(Vector{T}(undef,0),[one(T)])

"""
$(TYPEDSIGNATURES)

Create an empty VariableTargetAdjacency with default type
"""
VariableTargetAdjacency()=VariableTargetAdjacency(Int64)


"""
$(TYPEDSIGNATURES)

Create a VariableTargetAdjacency from Matrix
"""
VariableTargetAdjacency(m::Matrix{T}) where T=VariableTargetAdjacency{T}(vec(m),collect(1:size(m,1):size(m,1)*size(m,2)+1))

"""
$(TYPEDSIGNATURES)

Show adjacency (in trasposed form; preliminary)
"""
function Base.show(io::IO,adj::VariableTargetAdjacency)
    for isource=1:num_sources(adj)
        for itarget=1:num_targets(adj,isource)
            print(io,adj[itarget,isource], " ")
        end
        println(io, " ");
    end
end

"""
$(TYPEDSIGNATURES)

Access adjacency as if it is a 2D Array
"""
Base.getindex(adj::VariableTargetAdjacency,i,isource)=adj.colentries[adj.colstart[isource]+i-1]
Base.getindex(adj::VariableTargetAdjacency,::Colon,isource)=adj.colentries[adj.colstart[isource]:adj.colstart[isource+1]-1]

"""
$(TYPEDSIGNATURES)

Number of targets for given source
"""
num_targets(adj::VariableTargetAdjacency,isource)=adj.colstart[isource+1]-adj.colstart[isource]

"""
$(TYPEDSIGNATURES)

Number of sources in adjacency
"""
num_sources(adj::VariableTargetAdjacency)=length(adj.colstart)-1

"""
$(TYPEDSIGNATURES)

Number of targeta
"""
num_targets(adj::VariableTargetAdjacency)=maximum(adj.colentries)

"""
$(TYPEDSIGNATURES)

Number of links
"""
num_links(adj::VariableTargetAdjacency)=length(adj.colentries)

"""
$(TYPEDSIGNATURES)

Maximum number of targets per source
"""
max_num_targets_per_source(adj::VariableTargetAdjacency)=maximum(adj.colstart[2:end].-adj.colstart[1:end-1])

Base.size(adj::VariableTargetAdjacency)=(max_num_targets_per_source(adj),num_sources(adj))


function Matrix(adj::VariableTargetAdjacency{T}) where T
    m=zeros(T,size(adj)...)
    for isrc=1:num_sources(adj)
        for itgt=1:num_targets(adj,isrc)
            m[itgt,isrc]=adj[itgt,isrc]
        end
    end
    m
end
"""
$(TYPEDSIGNATURES)

Append a column to adjacency.
"""
function Base.append!(adj::VariableTargetAdjacency,column)
    for i=1:length(column)
        push!(adj.colentries,column[i])
    end
    push!(adj.colstart,length(adj.colentries)+1)
end

"""
$(TYPEDEF)

Use Matrix to store fixed target adjacency
"""
const FixedTargetAdjacency{T} =Matrix

"""
$(TYPEDSIGNATURES)

Number of targets per source if adjacency is a matrix
"""
num_targets(adj::FixedTargetAdjacency,isource)=size(adj)[1]

"""
$(TYPEDSIGNATURES)

Number of sources in adjacency
"""
num_sources(adj::FixedTargetAdjacency)=size(adj)[2]

"""
$(TYPEDSIGNATURES)

Overall number of targets 
"""
num_targets(adj::FixedTargetAdjacency)=maximum(vec(adj))

"""
$(TYPEDSIGNATURES)

Number of entries
"""
num_links(adj::FixedTargetAdjacency)=length(adj)

"""
$(TYPEDSIGNATURES)

Maximum number of targets per source
"""
max_num_targets_per_source(adj::FixedTargetAdjacency)=size(adj,1)

"""
$(TYPEDEF)

Adjacency type as union of FixedTargetAdjacency and VariableTargetAdjacency
"""
const Adjacency{T}=Union{FixedTargetAdjacency{T},VariableTargetAdjacency{T}}

"""
$(TYPEDSIGNATURES)

Constructors for Adjacency
"""
Adjacency{T}(a::FixedTargetAdjacency{T}) where T =a
Adjacency{T}(a::VariableTargetAdjacency{T}) where T =a

"""

Transpose adjacency
"""
function atranspose(adj::Adjacency{T}) where T
    # 0th pass: calculate number of rows !!! todo: how to call ?
    t_adj=VariableTargetAdjacency(zeros(T,num_links(adj)),zeros(T,num_targets(adj)+1))
    
    # 1st pass: calculate new column sizes, store them in t_adj.colstart
    for isource=1:num_sources(adj)
        for itarget=1:num_targets(adj,isource)
            t_adj.colstart[adj[itarget,isource]]+=1
        end
    end
    
    # 2nd pass: calculate initial assembly
    # addresses in adj.ja by summing up deltas
    # store them a the ends of  the columns:
    # in t_adj.ja[t_adj.colstart[isource+1]-1].
    # it will be overwritten when the last element of
    # the column is assembled.
    # We get automatically increasing  column indices.
    
    delta=t_adj.colstart[1];
    t_adj.colstart[1]=1;
    for isource=2:num_sources(t_adj)
	save=t_adj.colstart[isource];
	t_adj.colstart[isource]=t_adj.colstart[isource-1]+delta; 
	if delta>0
            t_adj.colentries[t_adj.colstart[isource]-1]=t_adj.colstart[isource-1];
        end
	delta=save;
    end
    isource=num_sources(t_adj)+1
    t_adj.colstart[isource]=t_adj.colstart[isource-1]+delta;
    if delta>0
        t_adj.colentries[t_adj.colstart[isource]-1]=t_adj.colstart[isource-1];
    end
    
    # 3rd pass: assemble new columns
    for isource=1:num_sources(adj)
        for itarget=1:num_targets(adj,isource)
	    asm_idx=t_adj.colstart[adj[itarget,isource]+1]-1;
	    asm_loc=t_adj.colentries[asm_idx];
	    t_adj.colentries[asm_idx]+=1; 
	    t_adj.colentries[asm_loc]=isource;
        end
    end
    return t_adj
end

