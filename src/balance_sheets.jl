using PrettyTables

# Balance sheet structures
struct BalanceSheet
    assets::Dict{String, Float64}
    liabilities::Dict{String, Float64}
    
    function BalanceSheet(assets, liabilities)
        new(assets, liabilities)
    end
end

struct SectorBalanceSheets
    private::BalanceSheet
    banks::BalanceSheet
    central_bank::BalanceSheet
end

# Calculate balance sheets from model solution
function get_balance_sheets(sol, params::SimplePKModelParams)
    Y, ND, D, r, i, P, dL, dM, dR, W, N, U = sol.u
    
    # Private Sector Balance Sheet
    private = BalanceSheet(
        Dict(
            "Deposits (D)" => D,
            "Total Assets" => D
        ),
        Dict(
            "Loans (L)" => dL,
            "Net Worth" => D - dL,
            "Total Liabilities" => D
        )
    )
    
    # Banking Sector Balance Sheet
    banks = BalanceSheet(
        Dict(
            "Loans (L)" => dL,
            "Reserves (R)" => dR,
            "Total Assets" => dL + dR
        ),
        Dict(
            "Deposits (D)" => D,
            "Central Bank Money (M)" => dM,
            "Total Liabilities" => D + dM
        )
    )
    
    # Central Bank Balance Sheet
    central_bank = BalanceSheet(
        Dict(
            "Reserves (R)" => dR,
            "Total Assets" => dR
        ),
        Dict(
            "Money Supply (M)" => dM,
            "Total Liabilities" => dM
        )
    )
    
    return SectorBalanceSheets(private, banks, central_bank)
end

# Display a single balance sheet
function display_balance_sheet(bs::BalanceSheet, sector_name::String)
    println("\n" * "="^60)
    println("  $sector_name")
    println("="^60)
    
    # Prepare data for the table
    max_rows = max(length(bs.assets), length(bs.liabilities))
    
    asset_keys = collect(keys(bs.assets))
    liability_keys = collect(keys(bs.liabilities))
    
    data = Matrix{Any}(undef, max_rows, 4)
    
    for i in 1:max_rows
        # Assets column
        if i <= length(asset_keys)
            data[i, 1] = asset_keys[i]
            data[i, 2] = round(bs.assets[asset_keys[i]], digits=2)
        else
            data[i, 1] = ""
            data[i, 2] = ""
        end
        
        # Liabilities column
        if i <= length(liability_keys)
            data[i, 3] = liability_keys[i]
            data[i, 4] = round(bs.liabilities[liability_keys[i]], digits=2)
        else
            data[i, 3] = ""
            data[i, 4] = ""
        end
    end
    
    pretty_table(data;
        column_labels = ["Assets", "Value", "Liabilities", "Value"],
        alignment = [:l, :r, :l, :r]
    )
end

# Display all balance sheets
function display_all_balance_sheets(sheets::SectorBalanceSheets)
    display_balance_sheet(sheets.private, "PRIVATE SECTOR")
    display_balance_sheet(sheets.banks, "BANKING SECTOR")
    display_balance_sheet(sheets.central_bank, "CENTRAL BANK")
    
    # Check accounting consistency
    println("\n" * "="^60)
    println("  ACCOUNTING CHECKS")
    println("="^60)
    
    total_deposits_assets = sheets.private.assets["Deposits (D)"]
    total_deposits_liab = sheets.banks.liabilities["Deposits (D)"]
    deposits_match = isapprox(total_deposits_assets, total_deposits_liab, rtol=1e-6)
    
    total_loans_liab = sheets.private.liabilities["Loans (L)"]
    total_loans_assets = sheets.banks.assets["Loans (L)"]
    loans_match = isapprox(total_loans_liab, total_loans_assets, rtol=1e-6)
    
    total_money_liab = sheets.banks.liabilities["Central Bank Money (M)"]
    total_money_assets = sheets.central_bank.liabilities["Money Supply (M)"]
    money_match = isapprox(total_money_liab, total_money_assets, rtol=1e-6)
    
    total_reserves_assets = sheets.banks.assets["Reserves (R)"]
    total_reserves_cb = sheets.central_bank.assets["Reserves (R)"]
    reserves_match = isapprox(total_reserves_assets, total_reserves_cb, rtol=1e-6)
    
    check_data = [
        "Deposits" deposits_match ? "✓" : "✗";
        "Loans" loans_match ? "✓" : "✗";
        "Money Supply" money_match ? "✓" : "✗";
        "Reserves" reserves_match ? "✓" : "✗"
    ]
    
    pretty_table(check_data;
        column_labels = ["Account", "Match"],
        alignment = [:l, :c]
    )
end

# Example usage:
# model = SimplePKModel()
# sol = solve_model(model)
# sheets = get_balance_sheets(sol, model.params)
# display_all_balance_sheets(sheets)