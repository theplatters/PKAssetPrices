const COLORS = (
    ink = "#172033",
    muted = "#647084",
    primary = "#315b7d",
    primary_light = "#5f8faa",
    accent = "#b56a45",
    teal = "#3e8179",
    grid = "#dfe5e8",
    paper = "#fffefa",
    canvas = "#f3f1eb",
)

const PLOT_FONT = "Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"

format_value(value::Number; digits = 4) = string(round(value; digits))
format_value(value; digits = 4) = string(value)
