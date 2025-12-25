function generate_balance_sheets_helper_methods(balance_sheets, model_name, variables)
    helper_methods = Expr[]
    for balance_sheet in balance_sheets
        push!(helper_methods, generate_helper_methods(balance_sheet, model_name, variables))
    end
    return helper_methods
end

function generate_helper_methods(balance_sheet, model_name, variables)
    type_name = Symbol(model_name, balance_sheet.name)
    assets_sum = if isempty(balance_sheet.assets)
        :(0.0)
    else
        Expr(:call, :+, [:(bs.$field) for field in balance_sheet.assets]...)
    end

    liabilities_sum = if isempty(balance_sheet.liabilities)
        :(0.0)
    else
        Expr(:call, :+, [:(bs.$field) for field in balance_sheet.liabilities]...)
    end

    net_worth_method = quote
        function net_worth(bs::$type_name)
            return $assets_sum - $liabilities_sum
        end
    end

    # Generate total_assets method
    total_assets_method = quote
        function total_assets(bs::$type_name)
            $assets_sum
        end
    end

    # Generate total_liabilities method
    total_liabilities_method = quote
        function total_liabilities(bs::$type_name)
            $liabilities_sum
        end
    end

    # Generate method to get assets as Dict
    assets_dict_method = quote
        function assets_dict(bs::$type_name)
            return Dict{String, Float64}(
                $([:($(String(field)) => bs.$field) for field in balance_sheet.assets]...)
            )
        end
    end

    # Generate method to get liabilities as Dict
    liabilities_dict_method = quote
        function liabilities_dict(bs::$type_name)
            return Dict{String, Float64}(
                $([:($(String(field)) => bs.$field) for field in balance_sheet.liabilities]...)
            )
        end
    end

    # Generate display method
    display_method = quote
        function display_balance_sheet(bs::$type_name, sector_name::String = "Balance Sheet")
            println("\n" * "="^60)
            println("  $sector_name")
            println("="^60)

            assets = assets_dict(bs)
            liabilities = liabilities_dict(bs)

            max_rows = max(length(assets), length(liabilities))

            asset_keys = collect(keys(assets))
            liability_keys = collect(keys(liabilities))

            # Print header
            println(rpad("ASSETS", 30) * " | " * rpad("LIABILITIES", 30))
            println("-"^60)

            # Print rows
            for i in 1:max_rows
                asset_str = if i <= length(asset_keys)
                    key = asset_keys[i]
                    name = replace(titlecase(key), "_" => " ")
                    value = round(assets[key], digits = 2)
                    rpad("$name: $value", 30)
                else
                    rpad("", 30)
                end

                liab_str = if i <= length(liability_keys)
                    key = liability_keys[i]
                    name = replace(titlecase(key), "_" => " ")
                    value = round(liabilities[key], digits = 2)
                    rpad("$name: $value", 30)
                else
                    rpad("", 30)
                end

                println(asset_str * " | " * liab_str)
            end

            # Print totals
            println("-"^60)
            total_a = total_assets(bs)
            total_l = total_liabilities(bs)
            nw = net_worth(bs)

            println(
                rpad("TOTAL: $(round(total_a, digits = 2))", 30) *
                    " | " *
                    rpad("TOTAL: $(round(total_l, digits = 2))", 30)
            )
            println("\nNet Worth: $(round(nw, digits = 2))")
            return println("="^60)
        end
    end


    calculations = values(balance_sheet.calculations)
    generate_sheet_from_solution = quote
        function get_sheet(::Type{$(type_name)}, sol)::$(type_name)
            (; $(variables...)) = sol
            return $(type_name)(
                $(calculations...)
            )
        end
    end


    # Return all generated code
    return quote
        $net_worth_method
        $total_assets_method
        $total_liabilities_method
        $assets_dict_method
        $liabilities_dict_method
        $display_method
        $generate_sheet_from_solution
    end
end


# Test it out
#=
private = Private(100.0, 50.0)
println("Private sector net worth: ", net_worth(private))  # 50.0
println("Private sector assets: ", total_assets(private))  # 100.0
println("Private sector liabilities: ", total_liabilities(private))  # 50.0

display_balance_sheet(private, "Private Sector")

banks = Banks(50.0, 20.0, 100.0, 20.0)
println("\nBanks net worth: ", net_worth(banks))  # -50.0
display_balance_sheet(banks, "Banking Sector")

cb = CentralBank(20.0, 20.0)
println("\nCentral Bank net worth: ", net_worth(cb))  # 0.0
display_balance_sheet(cb, "Central Bank")
lay_all_balance_sheets(sheets)
=#
