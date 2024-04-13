using Diversity

"""
    VirusTypes{TR <: AbstractTraits,
                 T <: AbstractTypes} <: AbstractTypes
VirusTypes holds information on the virus classes, such as the name of each class, their trait match to the environment, initial abundances and types.
"""
mutable struct VirusTypes{TR <: AbstractTraits,
                          T <: AbstractTypes} <: AbstractPathogenTypes
    names::Vector{String}
    traits::TR
    abun::Vector{Int64}
    types::T
    force_cats::Vector{Int64}

    function VirusTypes{TR, T}(names::Vector{String}, traits::TR,
                               abun::Vector{Int64}, types::T,
                               force_cats::Vector{Int64}) where {
                                                                 TR <:
                                                                 AbstractTraits,
                                                                 T <:
                                                                 AbstractTypes}
        return new{TR, T}(names, traits, abun, types, force_cats)
    end
    function VirusTypes{TR, T}(traits::TR, abun::Vector{Int64}, types::T,
                               force_cats::Vector{Int64}) where {
                                                                 TR <:
                                                                 AbstractTraits,
                                                                 T <:
                                                                 AbstractTypes}
        names = map(x -> "$x", 1:length(abun))
        return new{TR, T}(names, traits, abun, types, force_cats)
    end
end

"""
    HostTypes{MO <: AbstractMovement,
                 T <: AbstractTypes} <: AbstractTypes
HostTypes holds information on the host disease classes, such as the name of each class, their initial abundances and types, as well as how they disperse virus across the landscape.
"""
mutable struct HostTypes{MO <: AbstractMovement,
                         T <: AbstractTypes} <: AbstractSpeciesTypes
    names::Vector{String}
    abun::Vector{Int64}
    types::T
    movement::MO
    local_balance::Vector{Float64}
    region_balance::Vector{Float64}
    susceptible::Vector{Int64}
    infectious::Vector{Int64}
    host_to_force::Vector{Int64}

    function HostTypes{MO, T}(names::Vector{String}, abun::Vector{Int64},
                              types::T, movement::MO,
                              local_balance::Vector{Float64},
                              region_balance::Vector{Float64},
                              susceptible::Vector{Int64},
                              infectious::Vector{Int64},
                              host_to_force::Vector{Int64}) where {
                                                                   MO <:
                                                                   AbstractMovement,
                                                                   T <:
                                                                   AbstractTypes
                                                                   }
        return new{MO, T}(names, abun, types, movement, local_balance,
                          region_balance, susceptible, infectious,
                          host_to_force)
    end
    function HostTypes{MO, T}(abun::Vector{Int64}, types::T, movement::MO,
                              local_balance::Vector{Float64},
                              region_balance::Vector{Float64},
                              susceptible::Vector{Int64},
                              infectious::Vector{Int64},
                              host_to_force::Vector{Int64}) where {
                                                                   MO <:
                                                                   AbstractMovement,
                                                                   T <:
                                                                   AbstractTypes
                                                                   }
        names = map(x -> "$x", 1:length(abun))
        return new{MO, T}(names, abun, types, movement, local_balance,
                          region_balance, susceptible, infectious,
                          host_to_force)
    end
end

"""
    SpeciesList(traits::TR, virus_abun::DataFrame, host_abun::DataFrame,
                 movement::MO, transitions::DataFrame, params::NamedTuple,
                 age_categories::Int64 = 1, movement_balance::NamedTuple = (local_balance = fill(1.0, nrow(host_abun) * age_categories), region_balance = fill(0.0, nrow(host_abun) * age_categories))) where {TR <: AbstractTraits, MO <: AbstractMovement}

Function to create an `SpeciesList` for any type of epidemiological model - creating the correct number of classes and checking dimensions.
"""
function SpeciesList(traits::TR, virus_abun::DataFrame, host_abun::DataFrame,
                     movement::MO, transitions::DataFrame, params::NamedTuple,
                     age_categories::Int64 = 1,
                     movement_balance::NamedTuple = (local_balance = fill(1.0,
                                                                          nrow(host_abun) *
                                                                          age_categories),
                                                     region_balance = fill(0.0,
                                                                           nrow(host_abun) *
                                                                           age_categories))) where {
                                                                                                    TR <:
                                                                                                    AbstractTraits,
                                                                                                    MO <:
                                                                                                    AbstractMovement
                                                                                                    }
    # Test for susceptibility/infectiousness categories
    any(host_abun.type .== Infectious) ||
        error("No Infectious disease states")
    any(host_abun.type .== Susceptible) ||
        error("No Susceptible disease states")
    # Find correct indices in arrays
    row_sus = findall(==(Susceptible), host_abun.type)
    row_inf = findall(==(Infectious), host_abun.type)

    true_indices = [0; cumsum(length.(host_abun.initial))]
    idx_sus = vcat([(true_indices[r] + 1):true_indices[r + 1] for r in row_sus]...)
    idx_inf = vcat([(true_indices[r] + 1):true_indices[r + 1] for r in row_inf]...)
    length(idx_sus) == length(row_sus) * age_categories ||
        throw(DimensionMismatch("# susceptible categories is incorrect"))
    length(idx_inf) == length(row_inf) * age_categories ||
        throw(DimensionMismatch("# infectious categories is incorrect"))

    # Find their index locations in the names list
    names = host_abun.name
    abuns = vcat(host_abun.initial...)
    count = length.(host_abun.initial)

    h_names = vcat(collect.([(ifelse(count[j] == 1, names[j], names[j] * "$i")
                              for i in 1:count[j])
                             for j in eachindex(names)])...)
    ht = UniqueTypes(h_names)
    counttypes(ht) == nrow(host_abun) * age_categories ||
        throw(DimensionMismatch("# categories is inconsistent"))
    host_to_force = repeat(1:age_categories, nrow(host_abun))
    host = HostTypes{typeof(movement), typeof(ht)}(h_names, Int64.(abuns), ht,
                                                   movement,
                                                   movement_balance.local_balance,
                                                   movement_balance.region_balance,
                                                   idx_sus, idx_inf,
                                                   host_to_force)

    virus_names = virus_abun.name
    vabuns = vcat(virus_abun.initial...)
    vcount = length.(virus_abun.initial)
    v_names = vcat(collect.([(ifelse(vcount[j] == 1,
                                     virus_names[j], virus_names[j] * "$i")
                              for i in 1:vcount[j])
                             for j in eachindex(virus_names)])...)
    length(traits.mean) == length(v_names) ||
        throw(DimensionMismatch("Trait vector length ($(length(traits.mean))) doesn't match number of virus classes ($(length(v_names)))"))

    # TODO Need to stop "Force" being a required name in the virus list
    findfirst(v -> occursin("Force", v), v_names) ≡ nothing &&
        throw(DimensionMismatch("No Force term found"))
    force_cats = findall(occursin.("Force", v_names))

    vt = UniqueTypes(v_names)
    virus = VirusTypes{typeof(traits), typeof(vt)}(v_names, traits, vabuns, vt,
                                                   force_cats)

    transitions[!, :from_ind] = [findfirst(==(transitions[i, :from]), names)
                                 for i in eachindex(transitions[!, :from])]
    transitions[!, :to_ind] = [findfirst(==(transitions[i, :to]), names)
                               for i in eachindex(transitions[!, :to])]
    param = transition(params, transitions, length(names),
                       row_inf, age_categories)

    size(param.transition, 1) == length(h_names) ||
        throw(DimensionMismatch("Transition matrix doesn't match number of disease classes"))
    return SpeciesList{typeof(host), typeof(virus), typeof(param)}(host, virus,
                                                                   param)
end

function getnames(sppl::SpeciesList{A, B, C}) where {A <: HostTypes, B, C}
    return sppl.species.names
end

import Diversity.API._counttypes
function _counttypes(el::SpeciesList{A, B, C},
                     input::Bool) where {A <: HostTypes, B <: VirusTypes,
                                         C <: AbstractParams}
    return _counttypes(el.species.types, input) +
           _counttypes(el.pathogens.types, input)
end
function _counttypes(hm::HostTypes, input::Bool)
    return Diversity._counttypes(hm.types, input)
end
function _counttypes(vr::VirusTypes, input::Bool)
    return Diversity._counttypes(vr.types, input)
end
