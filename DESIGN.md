---
name: Ochre
description: A station departure board for your Mac's chip, where cores, processes and labels are split-flap tiles that flip with load.
colors:
  mustard: "#D6A92E"
  mustard-bright: "#E3B83C"
  heat-amber: "#E3BF5C"
  heat-ember: "#CC8F25"
  heat-red: "#B4462A"
  ground: "#18191B"
  board: "#2A2B2E"
  flap: "#36373B"
  flap-lit: "#3E3F43"
  rule: "#3A3B3F"
  ink: "#ECE7DA"
  ink-dim: "#B6B0A3"
  ink-faint: "#9C9689"
  ink-on-warm: "#1A1B1D"
  ink-on-heat: "#FBF3E6"
typography:
  display:
    fontFamily: "Golos Text, -apple-system, Helvetica Neue, Arial, sans-serif"
    fontSize: "clamp(2.35rem, 1.2rem + 3.9vw, 4.4rem)"
    fontWeight: 600
    lineHeight: 1.02
    letterSpacing: "-0.028em"
  headline:
    fontFamily: "Golos Text, -apple-system, Helvetica Neue, Arial, sans-serif"
    fontSize: "clamp(1.85rem, 1.25rem + 2.2vw, 3rem)"
    fontWeight: 600
    lineHeight: 1.06
    letterSpacing: "-0.024em"
  title:
    fontFamily: "Golos Text, -apple-system, Helvetica Neue, Arial, sans-serif"
    fontSize: "clamp(1.375rem, 1.05rem + 0.9vw, 1.875rem)"
    fontWeight: 600
    lineHeight: 1.1
    letterSpacing: "-0.01em"
  lede:
    fontFamily: "Golos Text, -apple-system, Helvetica Neue, Arial, sans-serif"
    fontSize: "clamp(1.0625rem, 1rem + 0.3vw, 1.25rem)"
    fontWeight: 400
    lineHeight: 1.55
  body:
    fontFamily: "Golos Text, -apple-system, Helvetica Neue, Arial, sans-serif"
    fontSize: "1.0625rem"
    fontWeight: 400
    lineHeight: 1.55
  caption:
    fontFamily: "Golos Text, -apple-system, Helvetica Neue, Arial, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.55
  flap:
    fontFamily: "Fira Sans Condensed, Arial Narrow, Helvetica Neue, sans-serif"
    fontSize: "1em"
    fontWeight: 600
    lineHeight: 1
    fontFeature: "tnum"
  label:
    fontFamily: "Fira Sans Condensed, Arial Narrow, Helvetica Neue, sans-serif"
    fontSize: "0.9375rem"
    fontWeight: 600
    lineHeight: 1
    letterSpacing: "0.02em"
rounded:
  cell: "2px"
  flap: "3px"
  chip: "4px"
  button: "6px"
  bar: "8px"
  strip: "10px"
  board: "14px"
  frame: "16px"
spacing:
  flap-gap-label: "2px"
  flap-gap: "3px"
  cell-gap: "5px"
  colhead: "10px"
  row: "13px"
  row-wide: "19px"
  block: "28px"
  board: "clamp(20px, 3.4vw, 44px)"
  gutter: "max(16px, min(48px, 4vw))"
  section: "clamp(72px, 9vw, 128px)"
  page: "1240px"
components:
  button-primary:
    backgroundColor: "{colors.mustard}"
    textColor: "{colors.ink-on-warm}"
    typography: "{typography.body}"
    rounded: "{rounded.button}"
    padding: "17px 24px"
  button-primary-hover:
    backgroundColor: "{colors.mustard-bright}"
    textColor: "{colors.ink-on-warm}"
  flap-tile:
    backgroundColor: "{colors.flap}"
    textColor: "{colors.ink}"
    typography: "{typography.flap}"
    rounded: "{rounded.flap}"
    height: "1.5em"
  flap-label:
    backgroundColor: "{colors.rule}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.flap}"
    height: "1.6em"
  board:
    backgroundColor: "{colors.board}"
    rounded: "{rounded.board}"
    padding: "{spacing.board}"
  chip:
    backgroundColor: "{colors.flap}"
    textColor: "{colors.ink}"
    rounded: "{rounded.chip}"
    padding: "9px 12px"
  tab:
    textColor: "{colors.ink-dim}"
    padding: "16px 4px"
  tab-selected:
    textColor: "{colors.mustard}"
  heat-step-amber:
    backgroundColor: "{colors.heat-amber}"
    textColor: "{colors.ink-on-warm}"
  heat-step-ember:
    backgroundColor: "{colors.heat-ember}"
    textColor: "{colors.ink-on-warm}"
  heat-step-red:
    backgroundColor: "{colors.heat-red}"
    textColor: "{colors.ink-on-heat}"
---

# Design System: Ochre

## Overview

**Creative North Star: "The Departure Board"**

The system is a Solari split-flap board read in a dim station hall. Graphite board housings sit on a darker ground; inside them, matte flap tiles split by a hairline carry warm off-white condensed glyphs. Cores, column heads, the brand mark, the language switch and the big temperature readout are all flaps, and they flip when their value changes. The board is the interface: information is arranged as departures, columns and ranked rows, never as a grid of feature cards.

Greys carry everything. The one chroma is mustard, and it is a measurement before it is a brand: warm colour means load or heat, rising from amber through ember to heat red. Outside the heat scale mustard is reserved for the primary action and for marking the current or focused thing. Empty flaps are active space, not filler; a label row is padded with blank tiles to the width of its longest language so switching languages flips letters in place rather than reflowing.

The system is a single committed dark theme (`color-scheme: dark`); there is no light variant. Real app captures appear framed inside it as light-mode evidence, not as a second theme.

**Key Characteristics:**
- Split-flap tiles as the signature unit: hairline seam, slightly darker lower leaf, tabular condensed glyphs.
- Graphite tonal layering instead of cards; boards are framed housings with column-head strips and ruled rows.
- One chroma, mustard, meaning load, heat, the primary action, or the current selection.
- Rank shown by type size alone (the busiest process row is the largest).
- Motion is mechanical: flaps fall and land; nothing fades in for decoration.

## Colors

A graphite-and-paper monochrome with a single mustard family that doubles as a heat scale.

### Primary
- **Station Mustard** (mustard): the download button, the CPU figures in departure rows, the selected tab title, the pressed language, the focus ring, link hover, text selection, and the arrow on the departure route. It is the only accent outside the heat scale.
- **Lit Mustard** (mustard-bright): the primary button's hover fill only.

### Secondary: the heat scale
Load and temperature are coloured by a continuous scale. Below 20% load a cell stays graphite; 20 to 60% blends Amber to Ember; 60 to 90% blends Ember to Heat Red; at 90% and above it is solid Heat Red. Temperatures step rather than blend: under 60° neutral, 60 to 80° amber, 80 to 95° ember, 95° and above heat.
- **Amber** (heat-amber): the first warm step; light, readable with dark ink.
- **Ember** (heat-ember): the middle of the scale; deep mustard.
- **Heat Red** (heat-red): rust; reserved for the hottest band and for tripped alerts.

### Neutral
- **Station Ground** (ground): the page behind every board.
- **Board Graphite** (board): the housing of every board, raised one tonal step above the ground.
- **Flap Charcoal** (flap): an idle flap tile, a cold GPU bar, chips, and the cold step of the heat strip.
- **Flap Lit** (flap-lit): scrollbar thumb; one step lighter than a tile.
- **Rule Grey** (rule): row rules, column-head underlines, board inner stroke, and the fill of label flaps.
- **Paper Ink** (ink): primary text and flap glyphs; warm off-white, never pure white.
- **Dim Ink** (ink-dim): lede, body copy in sections, secondary columns, unselected tabs, the unpressed language.
- **Faint Ink** (ink-faint): captions, notes, counts, footer.
- **Ink on Warm** (ink-on-warm): text on mustard, amber and ember fills.
- **Ink on Heat** (ink-on-heat): text on heat red, and on any heat-tinted flap from 83% load up, where the ember-to-red mix grows dark enough that light digits out-contrast dark ones.

### Named Rules
**The Colour Is a Measurement Rule.** A warm tone always means load, temperature, the primary action, or "this one is selected". Never use mustard or the heat colours as decoration, illustration fill, or section tint.

**The Light Digits at 83 Rule.** A heat-tinted tile switches its glyphs from Ink on Warm to Ink on Heat at 83% load. Below 20% (graphite) the glyphs are Paper Ink.

**The Graphite Steps Rule.** Depth is tonal: ground, then board, then flap, each one step lighter. Do not introduce a new grey between them; reuse the three steps.

## Typography

**Set Font:** Golos Text (with -apple-system, Helvetica Neue, Arial)
**Flap Font:** Fira Sans Condensed (with Arial Narrow, Helvetica Neue)

Both are self-hosted as Cyrillic and Latin subsets; every string exists in Russian and English, so any added face must cover Cyrillic.

**Character:** A calm, slightly humanist grotesk for reading, against a condensed grotesk that only ever appears as board lettering. The pairing is the difference between the announcement and the board.

### Hierarchy
- **Display** (600, fluid 2.35 to 4.4rem, 1.02, tight tracking): the one hero headline, balanced, about three lines.
- **Headline** (600, fluid 1.85 to 3rem, 1.06): section titles, max 20em wide.
- **Title** (600, fluid 1.375 to 1.875rem, 1.1): the top-ranked departure row and heat-strip step names.
- **Lede** (400, fluid 1.0625 to 1.25rem, 1.55): the hero subhead, max 34em, in Dim Ink.
- **Body** (400, 1.0625rem, 1.55): section copy, max 36em, in Dim Ink; also the button label at weight 600, line-height 1.
- **Caption** (400, 0.875rem): notes, figure captions, footnotes, footer, in Faint Ink.
- **Flap** (600, sized by its row, line-height 1, tabular figures): every flap glyph. Label rows run at 0.9375rem, figure rows at a fluid 1.4 to 1.9rem, core cells at 1.15 to 1.6rem, the temperature readout up to 6rem.
- **Label** (Fira Sans Condensed 600 or 500, 0.9375 to 1.25rem, slight positive tracking, uppercase for tab titles): tab titles, menu-bar item chips, heat-strip ranges, column heads. Column heads that are not flaps run at 0.8125rem, 0.08em tracking, uppercase.

### Named Rules
**The Board Lettering Rule.** Fira Sans Condensed is board lettering: flaps, column heads, tab titles, ranges, chips. Headlines and reading text stay in Golos Text.

**The Tabular Figures Rule.** Every changing number uses tabular figures so a flipping value never shifts its neighbours.

**The Rank by Size Rule.** Departure rows are ranked by type size alone (Title, then 1.25rem, 1.0625rem, 0.9375rem in Dim Ink); no badges, bars or numbering.

## Layout

Content sits in a centred page of 1240px plus a gutter of 16 to 48px (4vw), respecting safe-area insets. Sections are separated by generous vertical air (72 to 128px) and have no backgrounds of their own; the board housings are the only containers.

The hero is one wide board on a two-column grid (about 1.32 : 1): copy and die map on the left, departure rows and temperature on the right, the simulation note at the foot. At 1080px and below the copy spans the top; at 720px everything stacks and the Performance cluster folds from 12 to 6 columns. Secondary sections use a two-column split that stacks at 900px; the panel tour is a tab list beside a sticky capture column (max 400px) that becomes a wrapped row of chips at 760px. Tables (alerts, specs) drop their column-head strip and reflow to stacked rows at 560px.

Rhythm is tight inside boards and loose between them: flaps sit 2 to 3px apart, core cells 5px, column heads 10px above a 2px rule, rows 13px (19px on wide screens) between 1px rules, blocks 28px apart.

## Elevation & Depth

Depth is tonal layering with a few soft, low-contrast shadows; nothing floats. A board is lifted by its graphite step, an inner 1px stroke in Rule Grey, a faint top highlight, and a long soft drop beneath. Only the primary button carries a mustard glow, and only the round loupe and framed app captures cast their own soft drop. The flap itself carries depth mechanically: a hairline seam across its middle and a lower leaf mixed 8% toward black.

### Shadow Vocabulary
- **Board housing** (`box-shadow: inset 0 0 0 1px #3A3B3F, 0 1px 0 #ffffff08 inset, 0 24px 60px -30px #000`): every board.
- **Primary glow** (`box-shadow: 0 1px 0 #ffffff40 inset, 0 8px 20px -10px #d6a92e88`): the download button only.
- **Framed capture** (`box-shadow: 0 0 0 1px #ffffff14, 0 30px 60px -28px #000`): real app screenshots.

### Named Rules
**The Seam Not Shadow Rule.** A tile's depth comes from its seam and darker lower leaf, never from a drop shadow on the tile.

## Shapes

Rectangular and engineered, with small radii that grow with the size of the object: GPU bars and loupe cells 2 to 4px, flaps 3px (top corners on the upper leaf, bottom corners on the lower), chips and mobile tabs 4px, the button 6px, the menu-bar replica 8px, the heat strip 10px, boards 14px, framed captures 16px. The loupe is the one circle. Rules are flat lines: 2px under column heads and atop the tab list, 1px between rows.

## Components

### Buttons
Solid, warm, and singular.
- **Shape:** gently rounded (6px).
- **Primary:** mustard fill with Ink on Warm, Golos Text 600, 17px by 24px, an 18px stroked download arrow before the label. Full width at 720px and below. Beside it sits a Dim Ink fine-print line (price and footprint).
- **Hover / Active / Focus:** hover lifts the fill to Lit Mustard; active presses 1px down; focus shows the 2px mustard ring offset 3px. Transitions 0.2s on the ease-out curve.
- There is no secondary button style; text links inherit colour, underline at 1px, and turn mustard on hover.

### Split-flap tile (signature)
- A tile is two halves: upper leaf with 3px top corners, lower leaf with 3px bottom corners and 8% darker; a 1px black hairline (32% alpha) crosses the middle.
- **Figure flaps** sit in rows 3px apart and carry numbers; **label flaps** sit 2px apart on a Rule Grey fill with a lighter seam (18%) and no darker lower leaf, so headings recede behind data.
- A heat-tinted tile takes its fill from the heat scale and its ink by the Light Digits at 83 Rule.
- **Motion:** on value change the old upper leaf falls (110ms, accelerating, darkening to 70%) and the new lower leaf lands (110ms, decelerating, from 125% brightness). Rows ripple left to right with a per-letter stagger (about 22 to 60ms; 38ms default). On load the brand mark scrambles once to random letters and settles. Language switch flips every label in place. Under reduced motion values swap instantly with no flip.

### Boards and column heads
- **Board:** Board Graphite housing, 14px corners, fluid padding 20 to 44px, the board-housing shadow.
- **Column head:** a row of label flaps (Dim Ink counts in Faint Ink) over a 2px Rule Grey line; rows below are separated by 1px rules. Column heads are table headers for the data under them, never section labels above a headline.

### Departure rows
Process name, CPU (mustard, except the lowest rank in Dim Ink) and memory on a three-column grid; names truncate with an ellipsis. Rank is type size only.

### Heat test strip
Four equal steps in one 10px-rounded strip with a Rule Grey inner stroke: cold (Flap Charcoal, Paper Ink), Amber, Ember (Ink on Warm), Heat Red (Ink on Heat). Each step names its band in Title type and its load and temperature range in board lettering. Two columns at 720px.

### Tabs
A vertical list ruled 2px on top and 1px between entries: condensed uppercase title in Paper Ink over a Dim Ink description. The selected tab's title turns mustard; hover adds a 2% white wash; focus draws an inset mustard ring. At 760px tabs become wrapped Flap Charcoal chips (4px) and descriptions move below the capture.

### Chips
Flap Charcoal, 4px corners, 9px by 12px, Fira Sans Condensed 500 at 0.9375rem in Paper Ink. Static labels for options, not controls.

### Navigation
A thin top rail: icon plus flap wordmark at left; Dim Ink section links (hidden at 760px) and the RU/EN flap switch at right. The switch buttons are 44px targets; the pressed language's flaps carry mustard ink, the other Dim Ink, hover Paper Ink.

## Do's and Don'ts

### Do:
- **Do** build new data displays as boards: graphite housing, column-head strip of label flaps, ruled rows.
- **Do** colour load and temperature only through the heat scale (20/60/90 load stops; 60/80/95° temperature steps) and switch tile ink at 83% load.
- **Do** pad flap rows to the longest language's width so a language switch flips in place.
- **Do** use tabular figures for every live number.
- **Do** honour reduced motion by swapping values without flipping.
- **Do** keep mustard to load, heat, the primary action, and the current or focused item.

### Don't:
- **Don't** use feature-card grids, glass panels, or gradient surfaces; boards are the only containers.
- **Don't** place uppercase kicker or eyebrow labels above headlines; uppercase condensed lettering belongs to column heads and flaps.
- **Don't** use any chroma other than the mustard family, and don't use mustard or heat colours decoratively.
- **Don't** give tiles drop shadows; depth is the seam and the darker lower leaf.
- **Don't** add a light theme to the page; light-mode app captures are framed evidence inside the dark board.
- **Don't** set headlines or body copy in the condensed flap face.
