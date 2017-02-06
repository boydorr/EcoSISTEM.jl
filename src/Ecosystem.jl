using Diversity
using Diversity.AbstractPartition
using Diversity.AbstractMetacommunity
using Diversity.psmatch
using Diversity.AbstractSimilarity

## Habitat types
abstract AbstractHabitat

type Habitats <: AbstractHabitat
  matrix::Matrix{Float64}
end
type Niches <: AbstractHabitat
  matrix::Matrix{String}
end

# Env budget types
abstract AbstractBudget

type Budget <: AbstractBudget
  matrix::Matrix{Float64}
end

# Species trait types
abstract AbstractTraits

type StringTraits <: AbstractTraits
  traits::Vector{String}
end
type RealTraits <: AbstractTraits
  traits::Vector{Real}
end

type TraitRelationship
  matrix::Matrix{Real}
end

# Species energy types
abstract AbstractEnergy

type RealEnergy <: AbstractEnergy
  energy::Vector{Real}
end

# Species list type - all info on species

type SpeciesList{FP, M <: AbstractMatrix, A <: AbstractVector, N<: Any, B <: Any,
                             T <: AbstractTraits, E<: AbstractEnergy} <:
                             AbstractSimilarity{FP, M}
  similarity::M
  traits::T
  abun::A
  energy::E
  phylo::Tree{N,B}
end

function SpeciesList{FP <: AbstractFloat, A <: AbstractVector, N <: Any, B <: Any,
          T <: AbstractTraits, E<: AbstractEnergy}(similarity::AbstractMatrix{FP},
          traits::T, abun::A, energy::E, phylo::Tree{N,B})
  SpeciesList{FP, typeof(similarity), A, N, B, T, E}(similarity, traits, abun,
                                                     energy, tree)
end
function SpeciesList(NumberSpecies::Int64, NumberTraits::Int64,
                      abun_dist::Distribution, energy::AbstractVector)
  # error out when abun dist and NumberSpecies are not the same (same for energy dist)
  tree = jcoal(NumberSpecies, 100)
  trts = map(string, 1:NumberTraits)
  assign_traits!(tree, 0.2, trts)
  sp_trt = get_traits(tree, true)
  similarity = eye(NumberSpecies)
  abun = rand(abun_dist)
  length(abun)==NumberSpecies || throw(DimensionMismatch("Abundance vector
                                        doesn't match number species"))
  length(energy)==NumberSpecies || throw(DimensionMismatch("Energy vector
                                        doesn't match number species"))
  size(similarity)==(NumberSpecies,NumberSpecies) || throw(DimensionMismatch("
                              Similarity matrix doesn't match number species"))
  SpeciesList(similarity, StringTraits(sp_trt), abun,
                            RealEnergy(energy), tree)
end


# Abiotic environment types- all info about habitat and relationship to species
# traits
abstract AbstractAbiotic{H<: AbstractHabitat, R<: TraitRelationship, B<:AbstractBudget}

type AbioticEnv{H, R, B} <: AbstractAbiotic{H, R, B}
  habitat::H
  relationship::R
  budget::B
end
function AbioticEnv(NumberNiches::Int64, dimension::Tuple,
                    spplist::AbstractSpeciesList)
  niches = map(string, 1:NumberNiches)
  hab = random_habitat(dimension, niches, 0.5, [0.5,0.5])
  rel = eye(length(spplist.traits.traits), NumberNiches)
  bud = zeros(dimension)
  fill!(bud, 100)
  AbioticEnv(Niches(hab), TraitRelationship(rel), Budget(bud))
end

# Matrix Landscape types - houses abundances (initially empty)
abstract AbstractStructuredPartition{A} <: AbstractPartition{Float64, A}

type MatrixLandscape{A} <: AbstractStructuredPartition{A}
  abundances::A
end


function MatrixLandscape(abenv::AbstractAbiotic, spplist::AbstractSpeciesList)
  abundances=zeros(size(abenv.habitat.matrix,1),size(abenv.habitat.matrix,2),
             length(spplist.abun))
  MatrixLandscape(abundances)
end

# Ecosystem type - holds all information and populates ML
abstract AbstractEcosystem{A, Part <: AbstractStructuredPartition,
          S <: AbstractSpeciesList, AB <: AbstractAbiotic} <:
                AbstractMetacommunity{Float64, A, Part}

type Ecosystem{A, Part, S, AB} <: AbstractEcosystem{A, Part, S, AB}
  partition::Part
  ordinariness::Nullable{A}
  ssplist::S
  abenv::AB
end

function Ecosystem(spplist::AbstractSpeciesList, abenv::AbstractAbiotic)
  ml = MatrixLandscape(abenv, spplist)
  species = length(spplist.abun)
  populate!(ml, spplist, abenv)
  A = typeof(ml.abundances)
  Ecosystem(ml, Nullable{A}(), spplist, abenv)
end
