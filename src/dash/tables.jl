function variable_component(solution::Static.Solution)
  rows = map(solution.model.model.variables) do variable
    description = get(solution.model.model.variable_descriptions, variable, string(variable))
    html_tr(title=description) do
      html_th(string(variable), scope="row"),
      html_td(format_value(solution.variables[variable]; digits=6), className="numeric-cell")
    end
  end

  return html_div(className="table-scroll") do
    html_table(className="data-table variable-table") do
      html_thead() do
        html_tr() do
          html_th("Variable"),
          html_th("Equilibrium", className="numeric-cell")
        end
      end,
      html_tbody(rows)
    end
  end
end

function balance_sheet_row(sheet::Static.BalanceSheetFilled, index::Int)
  asset = index <= length(sheet.assets) ? sheet.assets[index] : nothing
  liability = index <= length(sheet.liabilities) ? sheet.liabilities[index] : nothing

  return html_tr() do
    html_td(isnothing(asset) ? "" : Static.title_from_snake(asset.first)),
    html_td(isnothing(asset) ? "" : format_value(asset.second; digits=2), className="numeric-cell"),
    html_td(isnothing(liability) ? "" : Static.title_from_snake(liability.first)),
    html_td(isnothing(liability) ? "" : format_value(liability.second; digits=2), className="numeric-cell")
  end
end

sheet_total(entries) = sum(entry -> entry.second, entries; init=0.0)

function table_from_balance_sheet(sheet::Static.BalanceSheetFilled)
  row_count = max(length(sheet.assets), length(sheet.liabilities))
  rows = [balance_sheet_row(sheet, index) for index in 1:row_count]

  return html_article(className="balance-sheet-card") do
    html_header(className="balance-sheet-heading") do
      html_div("Sector account", className="eyebrow"),
      html_h3(Static.title_from_snake(sheet.sector_name))
    end,
    html_div(className="table-scroll") do
      html_table(className="data-table balance-sheet-table") do
        html_thead() do
          html_tr() do
            html_th("Assets"),
            html_th("Value", className="numeric-cell"),
            html_th("Liabilities"),
            html_th("Value", className="numeric-cell")
          end
        end,
        html_tbody(rows),
        html_tfoot() do
          html_tr() do
            html_th("Total", scope="row"),
            html_td(format_value(sheet_total(sheet.assets); digits=2), className="numeric-cell"),
            html_th("Total", scope="row"),
            html_td(format_value(sheet_total(sheet.liabilities); digits=2), className="numeric-cell")
          end
        end
      end
    end
  end
end

function balance_sheet_component(solution::Static.Solution)
  isempty(solution.sheets) && return empty_state(
    "No sector accounts",
    "This model does not define balance sheets.",
  )
  return html_div(table_from_balance_sheet.(solution.sheets), className="balance-sheet-grid")
end

function variable_comparison_table(solutions, labels)
  all_variables = unique(vcat([collect(keys(solution.variables)) for solution in solutions]...))
  sort!(all_variables)
  descriptions = merge([solution.model.model.variable_descriptions for solution in solutions]...)

  header = Any[html_th("Variable")]
  append!(header, [html_th(label, className="numeric-cell") for label in labels])

  rows = map(all_variables) do variable
    values = map(solutions) do solution
      value = haskey(solution.variables, variable) ?
              format_value(solution.variables[variable]; digits=4) : "—"
      html_td(value, className="numeric-cell")
    end
    html_tr(
      vcat(Any[html_th(string(variable), scope="row")], values),
      title=get(descriptions, variable, string(variable)),
    )
  end

  return html_div(className="table-scroll") do
    html_table(className="data-table comparison-table") do
      html_thead(html_tr(header)),
      html_tbody(rows)
    end
  end
end

function balance_sheet_comparison_table(solutions, labels)
  cards = map(zip(solutions, labels)) do (solution, label)
    html_article(className="comparison-result-card") do
      html_header(className="comparison-result-heading") do
        html_div("Configuration", className="eyebrow"),
        html_h3(label)
      end,
      balance_sheet_component(solution)
    end
  end
  return html_div(cards, className="comparison-balance-grid")
end
