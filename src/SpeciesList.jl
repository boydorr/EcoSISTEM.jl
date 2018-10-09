using Diversity
using Phylo

"""
    SpeciesList{TR <: AbstractTraits, R <: AbstractRequirement,
                MO <: AbstractMovement, T <: AbstractTypes,
                P <: AbstractParams} <: AbstractTypes
Species list houses all species-specific information including trait information,
phylogenetic relationships, requirement for energy and movement types.
"""
mutable struct SpeciesList{TR <: AbstractTraits,
                 R <: AbstractRequirement,
                 MO <: AbstractMovement,
                 T <: AbstractTypes,
                 P <: AbstractParams} <: AbstractTypes
  names::Vector{String}
  traits::TR
  abun::Vector{Int64}
  requirement::R
  types::T
  movement::MO
  params::P
  native::Vector{Bool}

  function SpeciesList{TR, R, MO, T, P}(names:: Vector{String},
      traits::TR, abun::Vector{Int64}, req::R,
      types::T, movement::MO, params::P, native::Vector{Bool}) where {
                       TR <: AbstractTraits,
                       R <: AbstractRequirement,
                       MO <: AbstractMovement,
                       T <: AbstractTypes,
                       P <: AbstractParams}
      # Check dimensions
      equal_param = equalpop(params, length(names))
      new{TR, R, MO, T, typeof(equal_param)}(names, traits, abun, req, types,
       movement, equal_param, native)
  end
  function SpeciesList{TR, R, MO, T, P}(
      traits::TR, abun::Vector{Int64}, req::R,
      types::T, movement::MO, params::P, native::Vector{Bool}) where {
                       TR <: AbstractTraits,
                       R <: AbstractRequirement,
                       MO <: AbstractMovement,
                       T <: AbstractTypes,
                       P <: AbstractParams}
      # Check dimensions
      _simmatch(types)
      # Assign names
      names = map(x -> "$x", 1:length(abun))
      equal_param = equalpop(params, length(names))
      new{TR, R, MO, T, typeof(equal_param)}(names, traits, abun, req, types,
       movement, equal_param, native)
  end
end
"""
    SpeciesList{R <: AbstractRequirement,
      MO <: AbstractMovement, P <: AbstractParams}(numspecies::Int64,
      numtraits::Int64, abun_dist::Distribution, req::R,
      movement::MO, params::P)
Function to create a SpeciesList given a number of species, the number of traits
they possess, their abundances, requirement from the environment and their
movement kernel.
"""
function SpeciesList(numspecies::Int64,
    numtraits::Int64, abun_dist::Distribution, req::R,
    movement::MO, params::P, native::Vector{Bool}, switch::Vector{Float64}) where {R <: AbstractRequirement,
        MO <: AbstractMovement, P <: AbstractParams}

    names = map(x -> "$x", 1:numspecies)
    # Create tree
    tree = rand(Ultrametric{BinaryTree{DataFrame, DataFrame}}(names))
    # Create traits and assign to tips
    trts = DataFrame(trait1 = collect(1:numtraits))
    assign_traits!(tree, switch, trts)
    # Get traits from tree
    sp_trt = DiscreteTrait(Array(get_traits(tree, true)[:, 1]))
    # Create similarity matrix (for now identity)
    phy = PhyloTypes(tree)
    # Draw random set of abundances from distribution
    abun = rand(abun_dist)
    if length(abun) < numspecies
        abun = vcat(abun, repmat([0], numspecies - length(abun)))
    end
    # error out when abun dist and NumberSpecies are not the same (same for energy dist)
    length(abun)==numspecies || throw(DimensionMismatch("Abundance vector
                                          doesn't match number species"))
    length(req)==numspecies || throw(DimensionMismatch("Requirement vector
                                          doesn't match number species"))
  SpeciesList{typeof(sp_trt), typeof(req),
              typeof(movement), typeof(phy), typeof(params)}(names, sp_trt, abun,
              req, phy, movement, params, native)
end
function SpeciesList(numspecies::Int64,
    numtraits::Int64, abun_dist::Distribution, req::R,
    movement::MO, params::P, native::Vector{Bool}) where {R <: AbstractRequirement,
        MO <: AbstractMovement, P <: AbstractParams}
        return SpeciesList(numspecies, numtraits, abun_dist, req, movement,
                params, native, [0.5])
end


"""
    SpeciesList{R <: AbstractRequirement, MO <: AbstractMovement,
      T <: AbstractTypes, P <: AbstractParams}(numspecies::Int64,
      numtraits::Int64, abun_dist::Distribution, req::R,
      movement::MO, phy::T, params::P)
Function to create a SpeciesList given a number of species, the number of traits
they possess, their abundances, requirement from the environment and their
movement kernel and any type of AbstractTypes.
"""
function SpeciesList(numspecies::Int64,
    numtraits::Int64, abun_dist::Distribution, req::R,
    movement::MO, phy::T, params::P, native::Vector{Bool}) where
    {R <: AbstractRequirement, MO <: AbstractMovement,
        T <: AbstractTypes, P <: AbstractParams}

    names = map(x -> "$x", 1:numspecies)
    # Create tree
    tree = rand(Ultrametric{BinaryTree{DataFrame, DataFrame}}(names))
    # Create traits and assign to tips
    trts = DataFrame(trait1 = collect(1:numtraits))
    assign_traits!(tree, 0.5, trts)
    # Get traits from tree
    sp_trt = DiscreteTrait(Array(get_traits(tree, true)[:, 1]))
    # Draw random set of abundances from distribution
    abun = rand(abun_dist)
    if length(abun) < numspecies
        abun = vcat(abun, repmat([0], numspecies - length(abun)))
    end
    # error out when abun dist and NumberSpecies are not the same (same for energy dist)
    length(abun)==numspecies || throw(DimensionMismatch("Abundance vector
                                          doesn't match number species"))
    length(req)==numspecies || throw(DimensionMismatch("Requirement vector
                                          doesn't match number species"))
  SpeciesList{typeof(sp_trt), typeof(req),
              typeof(movement), typeof(phy), typeof(params)}(names, sp_trt, abun,
               req, phy, movement, params, native)
end



function SpeciesList(numspecies::Int64,
    traits::TR, abun_dist::Distribution, req::R,
    movement::MO, params::P, native::Vector{Bool}) where
    {TR<: AbstractTraits, R <: AbstractRequirement,
        MO <: AbstractMovement, P <: AbstractParams}

    names = map(x -> "$x", 1:numspecies)
    # Create similarity matrix (for now identity)
    ty = UniqueTypes(numspecies)
    # Draw random set of abundances from distribution
    abun = rand(abun_dist)
    if length(abun) < numspecies
        abun = vcat(abun, fill(0, numspecies - length(abun)))
    end
    # error out when abun dist and NumberSpecies are not the same (same for energy dist)
    length(abun)==numspecies || throw(DimensionMismatch("Abundance vector
                                          doesn't match number species"))
    length(req)==numspecies || throw(DimensionMismatch("Requirement vector
                                          doesn't match number species"))
  SpeciesList{typeof(traits), typeof(req),
              typeof(movement), typeof(ty),typeof(params)}(names, traits, abun,
              req, ty, movement, params, native)
end

function getenergyusage(sppl::SpeciesList)
    return _getenergyusage(sppl.abun, sppl.requirement)
end


function _simmatch(sim::SpeciesList)
  _simmatch(sim.types)
end

#function _calcsimilarity(ut::UniqueTypes)
#  return eye(ut.num)
#end

#function _calcsimilarity(ph::PhyloTypes)
# return ph.Zmatrix
#end
import Diversity.API: _gettypenames
function _gettypenames(sl::SpeciesList, input::Bool)
    return _gettypenames(sl.types, input)
end
import Diversity.API: _counttypes
function _counttypes(sl::SpeciesList, input::Bool)
    return _counttypes(sl.types, input)
end
import Diversity.API: _calcsimilarity
function _calcsimilarity(sl::SpeciesList, a::AbstractArray)
    return _calcsimilarity(sl.types, a)
end
import Diversity.API: _floattypes
function _floattypes(::SpeciesList)
    return Set([Float64])
end
import Diversity.API: _calcordinariness
function _calcordinariness(sl::SpeciesList, a::AbstractArray)
    _calcordinariness(sl.types, a, one(eltype(a)))
end
import Diversity.API: _calcabundance
function _calcabundance(sl::SpeciesList, a::AbstractArray)
  return _calcabundance(sl.types, a)
end
