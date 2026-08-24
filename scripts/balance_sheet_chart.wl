(* Balance sheet bar chart – replicates PDF panel *)

(* ── data from CSV ── *)
dL = 3.67167; dM = 3.67167; dR = 1.10150; SD = 0.388658;

(* ── colour palette (like Julia: blue assets, red liabilities) ── *)
assetCol  = RGBColor[0.20, 0.59, 0.86];
liabCol   = RGBColor[0.84, 0.25, 0.30];
lightBlue = RGBColor[0.35, 0.72, 0.93];
lightRed  = RGBColor[0.92, 0.50, 0.55];
blackEdge = Directive[Black, Opacity[0.65]];

(* ── stacked bars: Style[value, colour] per segment ── *)
bars = {
  {Style[dM, assetCol]},                                    (* PrivateSector · Assets *)
  {Style[dL, liabCol]},                                     (* PrivateSector · Liabilities *)
  {Style[dL, assetCol], Style[dR, lightBlue]},              (* Banks · Assets *)
  {Style[dM, liabCol],  Style[dR, lightRed]},               (* Banks · Liabilities *)
  {Style[dR, assetCol]},                                    (* CentralBank · Assets *)
  {Style[dR, liabCol]}                                      (* CentralBank · Liabilities *)
};

labels = {"Assets\nPrivate\nSector",
          "Liabilities\nPrivate\nSector",
          "Assets\nBanks",
          "Liabilities\nBanks",
          "Assets\nCentral\nBank",
          "Liabilities\nCentral\nBank"};

(* ── chart ── *)
BarChart[bars,
  ChartLayout -> "Stacked",
  BarOrigin -> Bottom,
  ChartLabels -> Placed[labels, Axis, Rotate[#, Pi/4, {0, 1}] &],
  LabelingFunction -> (Placed[NumberForm[#, {4, 3}], Center] &),
  Axes -> {False, True},
  Frame -> {{Left, False}, {Bottom, True}},
  FrameLabel -> {{None, None}, {None, Style["Amount", 12]}},
  GridLines -> {None, Automatic},
  GridLinesStyle -> Directive[Gray, Dashed, Opacity[0.2]],
  PlotRange -> {All, {0, 4.5}},
  ImageSize -> 520,
  AspectRatio -> 1 / GoldenRatio,
  PlotLabel -> Style["Sector Balance Sheets", Bold, 14]
]

(* ── annotations (sector names + indicators) ── *)
reserveRatio  = dR / dM;
totalLoans    = dL;
riskIndicator = SD / dL;

Graphics[{
  Text[Style["PrivateSector", Bold, 12], {1.5, 4.3}],
  Text[Style["Banks", Bold, 12],          {3.5, 4.3}],
  Text[Style["CentralBank", Bold, 12],   {5.5, 4.3}],
  Text[Style["Reserve ratio:  " <>
    ToString[NumberForm[reserveRatio, {4, 3}]], Medium],
    {5.9, 3.5}, {1, 0}],
  Text[Style["Total loans:  " <>
    ToString[NumberForm[totalLoans, {4, 3}]], Medium],
    {5.9, 2.5}, {1, 0}],
  Text[Style["Risk indicator:  " <>
    ToString[NumberForm[riskIndicator, {4, 3}]], Medium],
    {5.9, 1.5}, {1, 0}]
}]