function solution_component(solution::Static.Solution)
    return html_div(className = "solution-workbook") do
        html_div(className = "solution-summary") do
            html_div() do
                html_span(string(length(solution.variables)), className = "summary-value"),
                html_span("equilibrium variables", className = "summary-label")
            end,
            html_div() do
                html_span(string(length(solution.sheets)), className = "summary-value"),
                html_span("sector accounts", className = "summary-label")
            end,
            html_div() do
                html_span("Solved", className = "summary-value summary-status"),
                html_span("nonlinear system", className = "summary-label")
            end
        end,
        html_section(className = "workbook-section") do
            section_heading(
                "01 · Results ledger",
                "Computed equilibrium";
                description = "Hover over a variable name to read its economic definition.",
            ),
            html_div(className = "results-ledger-grid") do
                html_article(className = "paper-panel") do
                    section_heading("Variables", "Solution vector"; level = 3),
                    variable_component(solution)
                end,
                html_div(className = "balance-sheet-column") do
                    balance_sheet_component(solution)
                end
            end
        end,
        html_section(className = "workbook-section") do
            section_heading(
                "02 · Diagrams",
                "Equilibrium geometry";
                description = "Curves are recomputed from the selected parameterization.",
            ),
            html_div(className = "chart-grid") do
                is_ir_component(solution),
                ad_as_curve_component(solution)
            end
        end
    end
end

function curves_grid(solutions, labels)
    cards = map(zip(solutions, labels)) do (solution, label)
        html_article(className = "curve-comparison-card") do
            html_header(className = "comparison-result-heading") do
                html_div("Configuration", className = "eyebrow"),
                html_h3(label)
            end,
            html_div(className = "comparison-chart-stack") do
                is_ir_component(solution),
                ad_as_curve_component(solution)
            end
        end
    end
    return html_div(cards, className = "curve-comparison-grid")
end

"""Build the complete set of tables and diagrams for a model comparison."""
function comparison_results(solutions, labels)
    return html_div(className = "comparison-results") do
        html_section(className = "workbook-section") do
            section_heading(
                "01 · Comparative statics",
                "Equilibrium variables";
                description = "Each column reports one independently solved configuration.",
            ),
            html_article(className = "paper-panel") do
                variable_comparison_table(solutions, labels)
            end
        end,
        html_section(className = "workbook-section") do
            section_heading(
                "02 · Sector accounts",
                "Balance-sheet comparison";
                description = "Assets and liabilities are shown side by side for each configuration.",
            ),
            balance_sheet_comparison_table(solutions, labels)
        end,
        html_section(className = "workbook-section") do
            section_heading(
                "03 · Diagrams",
                "Curve comparison";
                description = "Matching axes make shifts across specifications easier to inspect.",
            ),
            curves_grid(solutions, labels)
        end
    end
end
