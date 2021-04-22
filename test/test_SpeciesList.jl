using EcoSISTEM
using Test
using Unitful.DefaultSymbols
using Distributions
using EcoSISTEM.Units
using Diversity

@testset "SpeciesList" begin
    ## Run simulation over a grid and plot
    numSpecies=4
    numTraits = 2

    # Set up how much energy each species consumes
    energy_vec = SimpleRequirement(fill(2.0, numSpecies))

    # Set probabilities
    birth = 6.0/year
    death = 6.0/year
    long = 1.0
    surv = 0.0
    boost = 1000.0
    timestep = 1.0month

    # Collect model parameters together (in this order!!)
    param = EqualPop(birth, death, long, surv, boost)

    individuals=100

    # Create ecosystem
    kernel = GaussianKernel.(fill(2.0km, numSpecies), 10e-4)
    movement = AlwaysMovement(kernel)

    opts = fill(5.0°C, numSpecies)
    vars = rand(Uniform(0, 25/9), numSpecies) * °C
    traits = GaussTrait(opts, vars)
    abun = rand(Multinomial(individuals, numSpecies))
    native = fill(true, numSpecies)
    @test_nowarn sppl = SpeciesList(numSpecies, traits, abun, energy_vec,
        movement, param, native)
    @test_nowarn sppl = SpeciesList(numSpecies, numTraits, abun,
                       energy_vec, movement, param, native)

    sppl = SpeciesList(numSpecies, traits, abun, energy_vec,
                           movement, param, native)
   # Test species types
   @test counttypes(sppl) == 4
   # Test pathogen types
   @test EcoSISTEM._counttypes(sppl.pathogens, true) == 0

   # Create new species list and test names
    species = SpeciesTypes{typeof(sppl.species.traits), typeof(sppl.species.requirement),
    typeof(sppl.species.movement), typeof(sppl.species.types)}(sppl.species.traits, sppl.species.abun,
    sppl.species.requirement, sppl.species.types, sppl.species.movement, sppl.species.native)

    newsppl = SpeciesList{typeof(species), NoPathogen, typeof(sppl.params)}(species, NoPathogen(), sppl.params)
    @test newsppl.species.names == sppl.species.names

    # Test mass based species list
    @test_nowarn SpeciesList(numSpecies, numTraits, 10.0, 10.0, 0.5, 100.0km^2, movement, param, native, [0.5, 0.5])

    # Test
    @test_nowarn sppl = SpeciesList(numSpecies, numTraits, abun, energy_vec, movement, UniqueTypes(numSpecies), param, native)

end
