using Mimi
using Distributions
using Query
using Plots
using DataFrames
using IterTools

mcs = @defmcs begin
    # Define random variables. The rv() is required to disambiguate an
    # RV definition name = Dist(args...) from application of a distribution
    # to an external parameter. This makes the (less common) naming of an
    # RV slightly more burdensome, but it's only required when defining
    # correlations or sharing an RV across parameters.
    rv(name1) = Normal(1, 0.2)
    rv(name2) = Uniform(0.75, 1.25)
    rv(name3) = LogNormal(20, 4)

    # define correlations
    name1:name2 = 0.7
    name1:name3 = 0.5

    # assign RVs to model Parameters
    share = Uniform(0.2, 0.8)
    sigma[:, Region1] *= name2
    sigma[2020:5:2050, (Region2, Region3)] *= Uniform(0.8, 1.2)

    depk[:] *= Uniform(0.7, 1.3)

    # indicate which parameters to save for each model run. Specify
    # a parameter name or [later] some slice of its data, similar to the
    # assignment of RVs, above.
    save(grosseconomy.K, grosseconomy.YGROSS, emissions.E, emissions.E_Global)
end

Mimi.reset_compdefs()
include("../../../examples/tutorial/02-two-region-model/main.jl")

m = model

# Optionally, user functions can be called just before or after a trial is run
function print_result(m::Model, mcs::MonteCarloSimulation, trialnum::Int)
    ci = Mimi.compinstance(m.mi, :emissions)
    value = Mimi.get_variable_value(ci, :E_Global)
    println("$(ci.comp_id).E_Global: $value")
end

N = 1000

output_dir = "/Volumes/RamDisk/Mimi-no-scen"

generate_trials!(mcs, N, filename=joinpath(output_dir, "trialdata.csv"))

# Run trials 1:N, and save results to the indicated directory

Mimi.set_model!(mcs, m)

run_mcs(mcs, N, output_dir=output_dir)

# From MCS discussion 5/23/2018
# generate_trials(mcs, samples=load("foo.csv"))
#
# run_mcs(mcs, [:foo=>m1,:bar=>m2], output_vars=[:foo=>[:grosseconomy=>[:bar,:bar2,:bar3], :comp2=>:var2], :bar=>[]], N, output_dir="/tmp/Mimi")
# run_mcs(mcs, m1, output_vars=[:grosseconomy=>:asf, :foo=>:bar], N, output_dir="/tmp/Mimi")
# run_mcs(mm, output_vars=[(:base,:compname,:varname), (:)], N, output_dir="/tmp/Mimi")
# run_mcs(mcs, mcs, mm, output_vars=[:grosseconomy=>:asf, :foo=>:bar], N, output_dir="/tmp/Mimi")
# run_mcs(mcs, m, output_vars=[(:base,:compname,:varname), (:)], N, output_dir="/tmp/Mimi")

# run_mcs(mcs, m, N, post_trial_func=print_result, output_dir="/tmp/Mimi")

function show_E_Global(year::Int; bins=40)
    df = @from i in E_Global begin
             @where i.time == year
             @select i
             @collect DataFrame
        end
    histogram(df[:E_Global], bins=bins, 
              title="Distribution of global emissions in $year",
              xlabel="Emissions")
end

#
# Test scenario loop capability
#
function my_loop_func(mcs::MonteCarloSimulation, tup)
    # unpack tuple (better to use NT here?)
    (scen, rate) = tup
    Mimi.log_info("scen:$scen, rate:$rate")
end

output_dir = "/Volumes/RamDisk/Mimi-scen"

run_mcs(mcs, 1000;
        output_dir=output_dir,
        scenario_func=my_loop_func, 
        scenario_args=[:scen => [:low, :med, :high],
                       :rate => [0.015, 0.03, 0.05]],
        scenario_placement=Mimi.OUTER)
 