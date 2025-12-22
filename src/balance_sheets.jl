
# Macro to mark fields as assets or liabilities
macro balance(struct_def)
    # Parse the struct definition
    if struct_def.head != :struct
        error("@balance can only be applied to struct definitions")
    end
    
    mutable = struct_def.args[1]
    struct_name = struct_def.args[2]
    struct_body = struct_def.args[3]
    
    # Extract type name if it's a complex expression (e.g., with type parameters)
    if struct_name isa Expr && struct_name.head == :<:
        type_name = struct_name.args[1]
    else
        type_name = struct_name
    end
    
    # Parse fields and their tags
    asset_fields = Symbol[]
    liability_fields = Symbol[]
    new_fields = []
    
    for expr in struct_body.args
        if expr isa LineNumberNode
            push!(new_fields, expr)
            continue
        end
        
        if expr isa Expr
            # Check for macro annotations
            if expr.head == :macrocall
                macro_name = expr.args[1]
                field_expr = expr.args[3]
                
                # Extract field name and type
                if field_expr isa Symbol
                    field_name = field_expr
                    field_type = :Any
                elseif field_expr isa Expr && field_expr.head == :(::)
                    field_name = field_expr.args[1]
                    field_type = field_expr.args[2]
                else
                    error("Unexpected field expression: $field_expr")
                end
                
                # Categorize based on macro
                if macro_name == Symbol("@asset")
                    push!(asset_fields, field_name)
                elseif macro_name == Symbol("@liability")
                    push!(liability_fields, field_name)
                else
                    error("Unknown macro: $macro_name. Use @asset or @liability")
                end
                
                # Add the field without the macro annotation
                push!(new_fields, :($field_name::$field_type))
            else
                # Regular field without annotation
                push!(new_fields, expr)
            end
        end
    end
    
    # Create new struct body
    new_struct_body = Expr(:block, new_fields...)
    
    # Generate the struct definition
    struct_expr = Expr(:struct, mutable, struct_name, new_struct_body)
    
    # Generate net_worth method
    assets_sum = if isempty(asset_fields)
        :(0.0)
    else
        Expr(:call, :+, [:(bs.$field) for field in asset_fields]...)
    end
    
    liabilities_sum = if isempty(liability_fields)
        :(0.0)
    else
        Expr(:call, :+, [:(bs.$field) for field in liability_fields]...)
    end
    
    net_worth_method = quote
        function net_worth(bs::$type_name)
            $assets_sum - $liabilities_sum
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
            Dict{String, Float64}(
                $([:($(String(field)) => bs.$field) for field in asset_fields]...)
            )
        end
    end
    
    # Generate method to get liabilities as Dict
    liabilities_dict_method = quote
        function liabilities_dict(bs::$type_name)
            Dict{String, Float64}(
                $([:($(String(field)) => bs.$field) for field in liability_fields]...)
            )
        end
    end
    
    # Generate display method
    display_method = quote
        function display_balance_sheet(bs::$type_name, sector_name::String="Balance Sheet")
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
                    value = round(assets[key], digits=2)
                    rpad("$name: $value", 30)
                else
                    rpad("", 30)
                end
                
                liab_str = if i <= length(liability_keys)
                    key = liability_keys[i]
                    name = replace(titlecase(key), "_" => " ")
                    value = round(liabilities[key], digits=2)
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
            
            println(rpad("TOTAL: $(round(total_a, digits=2))", 30) * 
                   " | " * 
                   rpad("TOTAL: $(round(total_l, digits=2))", 30))
            println("\nNet Worth: $(round(nw, digits=2))")
            println("="^60)
        end
    end
    
    # Return all generated code
    return esc(quote
        $struct_expr
        $net_worth_method
        $total_assets_method
        $total_liabilities_method
        $assets_dict_method
        $liabilities_dict_method
        $display_method
    end)
end

# Example usage:
@balance struct Private
    @asset deposits::Float64
    @liability loans::Float64
end

@balance struct Banks
    @asset loans::Float64
    @asset reserves::Float64
    @liability deposits::Float64
    @liability central_bank_money::Float64
end

@balance struct CentralBank
    @asset reserves::Float64
    @liability money_supply::Float64
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
